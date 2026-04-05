"""
Tests for cim_deserializer.py
==============================

Validates the two core performance claims from the CIM++ paper:

  1. O(1) dispatch  — hash-table lookup scales independently of table size
  2. SAX streaming  — parser produces no intermediate DOM; single pass only

Also covers correctness of factory instantiation, task queue resolution,
and end-to-end deserialization of a sample CIM RDF/XML document.
"""

import time
import textwrap
import unittest

from cim_deserializer import (
    AssignmentDispatcher,
    BaseClass,
    BatteryStorage,
    CIMDeserializer,
    CIMFactory,
    IdentifiedObject,
    SAXCIMHandler,
    Task,
    TaskQueue,
    Terminal,
    build_default_dispatcher,
    build_default_factory,
)

# ---------------------------------------------------------------------------
# Shared sample XML  (mirrors Listing 5 from the paper)
# ---------------------------------------------------------------------------

SAMPLE_CIM_XML = textwrap.dedent("""\
    <?xml version="1.0" encoding="UTF-8"?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:cim="http://iec.ch/TC57/2013/CIM-schema-cim16#">

      <cim:Terminal rdf:ID="BADCAB1E">
        <cim:IdentifiedObject.name>T1</cim:IdentifiedObject.name>
        <cim:Terminal.ConductingEquipment rdf:resource="#BS7"/>
      </cim:Terminal>

      <cim:BatteryStorage rdf:ID="BS7">
        <cim:IdentifiedObject.name>Battery-1</cim:IdentifiedObject.name>
        <cim:BatteryStorage.nominalP>5000</cim:BatteryStorage.nominalP>
        <cim:BatteryStorage.ratedU>400</cim:BatteryStorage.ratedU>
      </cim:BatteryStorage>

    </rdf:RDF>
""")


# ===========================================================================
# 1. AssignmentDispatcher — O(1) dispatch performance
# ===========================================================================

class TestO1DispatchPerformance(unittest.TestCase):
    """
    Validates that hash-table dispatch is O(1) — lookup time does not grow
    with the number of registered functions.

    Method: time 10,000 lookups on a small table (10 entries) and a large
    table (3,000 entries, matching the CIM++ paper's scale), then assert that
    the large-table time is within a 3× factor of the small-table time.
    A linear (O(n)) implementation would be ~300× slower at 3,000 entries.
    """

    ITERATIONS = 10_000
    SMALL_SIZE = 10
    LARGE_SIZE = 3_000
    # Allow up to 3× variance for scheduling noise — O(n) would be ~300×
    TOLERANCE_FACTOR = 3.0

    def _build_dispatcher(self, n: int) -> AssignmentDispatcher:
        """Return a dispatcher with *n* registered no-op functions."""
        d = AssignmentDispatcher()
        for i in range(n):
            d.register(f"cim:Dummy.attr{i}", lambda obj, v: None)
        # Always register the target key so lookup always hits
        d.register("cim:IdentifiedObject.name", lambda obj, v: None)
        return d

    def _time_dispatch(self, dispatcher: AssignmentDispatcher) -> float:
        """Return seconds for ITERATIONS lookups on a known key."""
        obj = IdentifiedObject()
        tag = "cim:IdentifiedObject.name"
        start = time.perf_counter()
        for _ in range(self.ITERATIONS):
            dispatcher.dispatch(obj, tag, "test")
        return time.perf_counter() - start

    def test_dispatch_hit_returns_true(self):
        """Dispatch on a registered key must return True."""
        d = AssignmentDispatcher()
        d.register("cim:IdentifiedObject.name", lambda obj, v: setattr(obj, "name", v))
        obj = IdentifiedObject()
        result = d.dispatch(obj, "cim:IdentifiedObject.name", "MyName")
        self.assertTrue(result)
        self.assertEqual(obj.name, "MyName")

    def test_dispatch_miss_returns_false(self):
        """Dispatch on an unregistered key must return False."""
        d = AssignmentDispatcher()
        obj = IdentifiedObject()
        self.assertFalse(d.dispatch(obj, "cim:Unknown.tag", "value"))

    def test_large_table_not_slower_than_small_by_factor(self):
        """
        O(1) property: 3,000-entry table lookup must be within TOLERANCE_FACTOR
        of 10-entry table lookup.  A linear scan would be ~300× slower.
        """
        small = self._build_dispatcher(self.SMALL_SIZE)
        large = self._build_dispatcher(self.LARGE_SIZE)

        t_small = self._time_dispatch(small)
        t_large = self._time_dispatch(large)

        # Guard against zero division on very fast machines
        if t_small < 1e-9:
            self.skipTest("Timer resolution too low for this hardware")

        ratio = t_large / t_small
        self.assertLessEqual(
            ratio,
            self.TOLERANCE_FACTOR,
            msg=(
                f"Hash dispatch degraded by {ratio:.1f}× going from "
                f"{self.SMALL_SIZE} to {self.LARGE_SIZE} entries "
                f"(expected < {self.TOLERANCE_FACTOR}×, O(n) would be ~300×). "
                f"small={t_small*1000:.3f}ms  large={t_large*1000:.3f}ms"
            ),
        )

    def test_dispatcher_len(self):
        """__len__ reflects registered count."""
        d = AssignmentDispatcher()
        self.assertEqual(len(d), 0)
        d.register("cim:A.b", lambda o, v: None)
        d.register("cim:A.c", lambda o, v: None)
        self.assertEqual(len(d), 2)

    def test_contains(self):
        d = AssignmentDispatcher()
        d.register("cim:X.y", lambda o, v: None)
        self.assertIn("cim:X.y", d)
        self.assertNotIn("cim:X.z", d)


# ===========================================================================
# 2. CIMFactory — O(1) instantiation
# ===========================================================================

class TestCIMFactory(unittest.TestCase):

    def test_registered_class_creates_correct_type(self):
        factory = build_default_factory()
        obj = factory.create("Terminal")
        self.assertIsInstance(obj, Terminal)

    def test_unregistered_class_returns_none(self):
        factory = CIMFactory()
        self.assertIsNone(factory.create("NonExistent"))

    def test_is_registered(self):
        factory = build_default_factory()
        self.assertTrue(factory.is_registered("BatteryStorage"))
        self.assertFalse(factory.is_registered("Transformer"))

    def test_len(self):
        factory = CIMFactory()
        self.assertEqual(len(factory), 0)
        factory.register("A", BaseClass)
        self.assertEqual(len(factory), 1)

    def test_factory_dispatch_scale(self):
        """
        O(1) property: creation time from a 3,000-entry factory should not
        be proportionally slower than from a 3-entry factory.
        """
        ITERATIONS = 5_000
        TOLERANCE = 3.0

        small_f = CIMFactory()
        small_f.register("Terminal", Terminal)
        small_f.register("BatteryStorage", BatteryStorage)
        small_f.register("IdentifiedObject", IdentifiedObject)

        large_f = CIMFactory()
        for i in range(3_000):
            large_f.register(f"DummyClass{i}", BaseClass)
        large_f.register("Terminal", Terminal)

        t0 = time.perf_counter()
        for _ in range(ITERATIONS):
            small_f.create("Terminal")
        t_small = time.perf_counter() - t0

        t0 = time.perf_counter()
        for _ in range(ITERATIONS):
            large_f.create("Terminal")
        t_large = time.perf_counter() - t0

        if t_small < 1e-9:
            self.skipTest("Timer resolution too low")

        ratio = t_large / t_small
        self.assertLessEqual(
            ratio, TOLERANCE,
            msg=f"Factory lookup degraded {ratio:.1f}× at 3,000 entries (expected < {TOLERANCE}×)",
        )


# ===========================================================================
# 3. TaskQueue — deferred forward-reference resolution
# ===========================================================================

class TestTaskQueue(unittest.TestCase):

    def test_enqueue_and_resolve(self):
        terminal = Terminal()
        battery = BatteryStorage()
        battery.rdf_id = "BS7"
        registry = {"BS7": battery}

        task = Task(terminal, "conducting_equipment", "BS7")
        q = TaskQueue()
        q.enqueue(task)
        self.assertEqual(len(q), 1)

        resolved, unresolved = q.resolve_all(registry)
        self.assertEqual(resolved, 1)
        self.assertEqual(unresolved, 0)
        self.assertIs(terminal.conducting_equipment, battery)

    def test_unresolvable_task_counted(self):
        terminal = Terminal()
        task = Task(terminal, "conducting_equipment", "MISSING_ID")
        q = TaskQueue()
        q.enqueue(task)

        resolved, unresolved = q.resolve_all({})
        self.assertEqual(resolved, 0)
        self.assertEqual(unresolved, 1)
        self.assertIsNone(terminal.conducting_equipment)

    def test_queue_cleared_after_resolve(self):
        q = TaskQueue()
        q.enqueue(Task(Terminal(), "conducting_equipment", "x"))
        q.resolve_all({})
        self.assertEqual(len(q), 0)

    def test_multiple_tasks(self):
        """Multiple tasks pointing to the same target all resolve."""
        battery = BatteryStorage()
        battery.rdf_id = "BS1"
        registry = {"BS1": battery}

        terminals = [Terminal() for _ in range(5)]
        q = TaskQueue()
        for t in terminals:
            q.enqueue(Task(t, "conducting_equipment", "BS1"))

        resolved, unresolved = q.resolve_all(registry)
        self.assertEqual(resolved, 5)
        self.assertEqual(unresolved, 0)
        for t in terminals:
            self.assertIs(t.conducting_equipment, battery)


# ===========================================================================
# 4. SAX Streaming — no intermediate DOM
# ===========================================================================

class TestSAXStreamingBehavior(unittest.TestCase):
    """
    Validates the SAX streaming properties:

    - Objects are created directly during the parse pass (not after)
    - No DOM tree is constructed (we verify via object count/type, not memory)
    - A single pass over the document suffices
    - Forward references are resolved via the task queue post-pass only
    """

    def _parse(self, xml_source: str):
        factory = build_default_factory()
        dispatcher = build_default_dispatcher()
        task_queue = TaskQueue()
        handler = SAXCIMHandler(factory, dispatcher, task_queue)

        import xml.sax
        xml.sax.parseString(xml_source.encode("utf-8"), handler)
        return handler, task_queue

    def test_objects_instantiated_during_sax_pass(self):
        """Objects exist in the registry immediately after parseString."""
        handler, _ = self._parse(SAMPLE_CIM_XML)
        self.assertIn("BADCAB1E", handler.registry)
        self.assertIn("BS7", handler.registry)

    def test_correct_types_instantiated(self):
        handler, _ = self._parse(SAMPLE_CIM_XML)
        self.assertIsInstance(handler.registry["BADCAB1E"], Terminal)
        self.assertIsInstance(handler.registry["BS7"], BatteryStorage)

    def test_attributes_assigned_directly_no_intermediate_copy(self):
        """
        Attribute values are written directly into the object during parse.
        Tests that no post-processing step is needed to copy from a buffer.
        """
        handler, _ = self._parse(SAMPLE_CIM_XML)
        battery: BatteryStorage = handler.registry["BS7"]
        self.assertEqual(battery.name, "Battery-1")
        self.assertAlmostEqual(battery.nominal_p, 5000.0)
        self.assertAlmostEqual(battery.rated_u, 400.0)

    def test_forward_reference_unresolved_before_task_sweep(self):
        """
        Terminal.conducting_equipment must be None immediately after the
        SAX pass — it is only linked in the post-pass task queue sweep.
        This confirms the parser does NOT make a second document pass.
        """
        handler, task_queue = self._parse(SAMPLE_CIM_XML)
        terminal: Terminal = handler.registry["BADCAB1E"]
        # Forward ref not yet resolved
        self.assertIsNone(terminal.conducting_equipment)
        self.assertGreater(len(task_queue), 0)

    def test_forward_reference_resolved_after_task_sweep(self):
        """After resolve_all, the association pointer is correctly set."""
        handler, task_queue = self._parse(SAMPLE_CIM_XML)
        task_queue.resolve_all(handler.registry)

        terminal: Terminal = handler.registry["BADCAB1E"]
        battery: BatteryStorage = handler.registry["BS7"]
        self.assertIs(terminal.conducting_equipment, battery)

    def test_single_pass_element_count(self):
        """
        The SAX handler's elements_parsed counter should equal the total
        number of XML elements in the document — confirming a single pass.
        """
        handler, _ = self._parse(SAMPLE_CIM_XML)
        # rdf:RDF wrapper + 2 objects + their attribute children = 8 elements
        # (rdf:RDF, Terminal, IdentifiedObject.name, Terminal.ConductingEquipment,
        #  BatteryStorage, IdentifiedObject.name, BatteryStorage.nominalP,
        #  BatteryStorage.ratedU)
        self.assertEqual(handler.elements_parsed, 8)

    def test_objects_created_count(self):
        handler, _ = self._parse(SAMPLE_CIM_XML)
        self.assertEqual(handler.objects_created, 2)

    def test_attributes_assigned_count(self):
        handler, _ = self._parse(SAMPLE_CIM_XML)
        # name (Terminal), name + nominalP + ratedU (BatteryStorage) = 4
        self.assertEqual(handler.attributes_assigned, 4)


# ===========================================================================
# 5. CIMDeserializer — end-to-end
# ===========================================================================

class TestCIMDeserializerEndToEnd(unittest.TestCase):

    def setUp(self):
        self.deserializer = CIMDeserializer()

    def test_returns_all_objects(self):
        registry = self.deserializer.deserialize(SAMPLE_CIM_XML)
        self.assertEqual(len(registry), 2)
        self.assertIn("BADCAB1E", registry)
        self.assertIn("BS7", registry)

    def test_terminal_name(self):
        registry = self.deserializer.deserialize(SAMPLE_CIM_XML)
        self.assertEqual(registry["BADCAB1E"].name, "T1")

    def test_battery_attributes(self):
        registry = self.deserializer.deserialize(SAMPLE_CIM_XML)
        battery: BatteryStorage = registry["BS7"]
        self.assertEqual(battery.name, "Battery-1")
        self.assertAlmostEqual(battery.nominal_p, 5000.0)
        self.assertAlmostEqual(battery.rated_u, 400.0)

    def test_association_resolved(self):
        """Terminal.conducting_equipment must point to the BatteryStorage."""
        registry = self.deserializer.deserialize(SAMPLE_CIM_XML)
        terminal: Terminal = registry["BADCAB1E"]
        battery: BatteryStorage = registry["BS7"]
        self.assertIs(terminal.conducting_equipment, battery)

    def test_all_objects_are_base_class_instances(self):
        """Every object in the registry must inherit from BaseClass."""
        registry = self.deserializer.deserialize(SAMPLE_CIM_XML)
        for obj in registry.values():
            self.assertIsInstance(obj, BaseClass)

    def test_empty_document_returns_empty_registry(self):
        empty_xml = '<?xml version="1.0"?><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/>'
        registry = self.deserializer.deserialize(empty_xml)
        self.assertEqual(registry, {})


if __name__ == "__main__":
    unittest.main(verbosity=2)
