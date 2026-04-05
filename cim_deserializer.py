#!/usr/bin/env python3
"""
CIM++ Deserializer — Python Implementation
==========================================

Ports the key architectural patterns from the CIM++ paper
(Razik et al., RWTH Aachen, 2017) into the NCOMM stack.

Patterns implemented
--------------------
1. BaseClass injection      — common polymorphic root (Sect. 5.1)
2. CIMFactory               — hash-table keyed instantiation, O(1) (Sect. 5.3)
3. AssignmentDispatcher     — hash-table keyed attribute routing, O(1) (Sect. 5.3)
4. SAXStreamingParser       — single-pass, zero-DOM event handler (Sect. 5.2)
5. TaskQueue                — deferred RDF forward-reference resolution (Sect. 5.3)

Reference: CIMpp-findings.md
"""

from __future__ import annotations

import re
import xml.sax
import xml.sax.handler
from typing import Callable, Dict, List, Optional, Tuple


# ---------------------------------------------------------------------------
# 1. BaseClass
# ---------------------------------------------------------------------------

class BaseClass:
    """
    Common root injected into all top-level CIM classes.

    Enables heterogeneous CIM objects to be stored in a single typed
    container — without void* or boost::any — by providing a shared
    base pointer type.  Mirrors Sect. 5.1 of the CIM++ paper.
    """

    def __init__(self) -> None:
        self.rdf_id: Optional[str] = None

    def __repr__(self) -> str:
        return f"<{self.__class__.__name__} rdf_id={self.rdf_id!r}>"


# ---------------------------------------------------------------------------
# 2. Sample CIM model classes  (normally auto-generated from UML ontology)
# ---------------------------------------------------------------------------

class IdentifiedObject(BaseClass):
    """CIM IdentifiedObject — carries a human-readable name."""

    def __init__(self) -> None:
        super().__init__()
        self.name: str = ""


class Terminal(IdentifiedObject):
    """CIM Terminal — connection point on a ConductingEquipment."""

    def __init__(self) -> None:
        super().__init__()
        self.conducting_equipment: Optional[BaseClass] = None


class BatteryStorage(IdentifiedObject):
    """
    Extended Sinergien class — not in the original IEC 61970 standard.
    Added to validate CIM++ flexibility (Sect. 7.1 of paper).
    """

    def __init__(self) -> None:
        super().__init__()
        self.nominal_p: float = 0.0
        self.rated_u: float = 0.0


# ---------------------------------------------------------------------------
# 3. Task — deferred forward-reference
# ---------------------------------------------------------------------------

class Task:
    """
    An unresolved RDF association link encountered during SAX parsing.

    Queued when a tag carries an rdf:resource attribute referencing an
    object that may not yet have been instantiated.  Resolved in a single
    post-pass once the full document has been parsed (Sect. 5.3).

    Attributes
    ----------
    source_obj    : object that owns the unresolved pointer attribute
    attr_name     : Python attribute to set once resolved
    target_rdf_id : rdf:ID of the object to link to
    """

    def __init__(
        self,
        source_obj: BaseClass,
        attr_name: str,
        target_rdf_id: str,
    ) -> None:
        self.source_obj = source_obj
        self.attr_name = attr_name
        self.target_rdf_id = target_rdf_id

    def resolve(self, registry: Dict[str, BaseClass]) -> bool:
        """Assign the pointer if the target exists. Returns True on success."""
        target = registry.get(self.target_rdf_id)
        if target is None:
            return False
        setattr(self.source_obj, self.attr_name, target)
        return True


# ---------------------------------------------------------------------------
# 4. TaskQueue
# ---------------------------------------------------------------------------

class TaskQueue:
    """
    FIFO queue of unresolved Tasks.

    After the SAX pass completes, ``resolve_all`` performs a single sweep
    using the completed object registry — avoiding multiple document passes.
    """

    def __init__(self) -> None:
        self._queue: List[Task] = []

    def enqueue(self, task: Task) -> None:
        self._queue.append(task)

    def resolve_all(self, registry: Dict[str, BaseClass]) -> Tuple[int, int]:
        """
        Resolve all pending tasks.

        Returns
        -------
        (resolved_count, unresolved_count)
        """
        resolved = unresolved = 0
        for task in self._queue:
            if task.resolve(registry):
                resolved += 1
            else:
                unresolved += 1
        self._queue.clear()
        return resolved, unresolved

    def __len__(self) -> int:
        return len(self._queue)


# ---------------------------------------------------------------------------
# 5. AssignmentDispatcher — O(1) attribute routing
# ---------------------------------------------------------------------------

AssignmentFn = Callable[[BaseClass, str], None]


class AssignmentDispatcher:
    """
    Hash-table mapping XML attribute tag names → assignment callables.

    Replaces the O(n) if-branch chain with an O(1) dict lookup.  In the
    C++ implementation function pointers are stored; here we use Python
    callables.  The CIM++ paper generates 3,000+ such functions for the
    full IEC 61970 model (Sect. 5.3).

    Example
    -------
    >>> d = AssignmentDispatcher()
    >>> d.register("cim:IdentifiedObject.name",
    ...            lambda obj, v: setattr(obj, "name", v))
    >>> d.dispatch(my_obj, "cim:IdentifiedObject.name", "Battery-1")
    True
    """

    def __init__(self) -> None:
        self._table: Dict[str, AssignmentFn] = {}

    def register(self, tag: str, fn: AssignmentFn) -> None:
        self._table[tag] = fn

    def dispatch(self, obj: BaseClass, tag: str, value: str) -> bool:
        """Invoke the handler for *tag*. Returns True if handled."""
        fn = self._table.get(tag)
        if fn is None:
            return False
        fn(obj, value)
        return True

    def __len__(self) -> int:
        return len(self._table)

    def __contains__(self, tag: str) -> bool:
        return tag in self._table


# ---------------------------------------------------------------------------
# 6. CIMFactory — O(1) object instantiation
# ---------------------------------------------------------------------------

FactoryFn = Callable[[], BaseClass]


class CIMFactory:
    """
    Maps CIM class name strings → factory callables (O(1) dict lookup).

    Mirrors the CIMFactory class auto-generated by the CIM-Unmarshalling-
    Generator in Sect. 5.3–5.4 of the paper.
    """

    def __init__(self) -> None:
        self._factories: Dict[str, FactoryFn] = {}

    def register(self, class_name: str, fn: FactoryFn) -> None:
        self._factories[class_name] = fn

    def create(self, class_name: str) -> Optional[BaseClass]:
        """Instantiate an object of *class_name*, or None if unregistered."""
        fn = self._factories.get(class_name)
        return fn() if fn is not None else None

    def is_registered(self, class_name: str) -> bool:
        return class_name in self._factories

    def __len__(self) -> int:
        return len(self._factories)


# ---------------------------------------------------------------------------
# 7. Default registry builders
# ---------------------------------------------------------------------------

def build_default_factory() -> CIMFactory:
    """CIMFactory pre-loaded with the sample CIM model classes."""
    factory = CIMFactory()
    factory.register("Terminal", Terminal)
    factory.register("BatteryStorage", BatteryStorage)
    factory.register("IdentifiedObject", IdentifiedObject)
    return factory


def build_default_dispatcher() -> AssignmentDispatcher:
    """
    AssignmentDispatcher pre-loaded with handlers for the sample model.
    Mirrors the auto-generated assignment functions in Sect. 5.3.
    """
    d = AssignmentDispatcher()
    d.register(
        "cim:IdentifiedObject.name",
        lambda obj, v: setattr(obj, "name", v.strip()),
    )
    d.register(
        "cim:BatteryStorage.nominalP",
        lambda obj, v: setattr(obj, "nominal_p", float(v.strip())),
    )
    d.register(
        "cim:BatteryStorage.ratedU",
        lambda obj, v: setattr(obj, "rated_u", float(v.strip())),
    )
    return d


# ---------------------------------------------------------------------------
# 8. SAXStreamingParser — single-pass, zero-DOM
# ---------------------------------------------------------------------------

def _camel_to_snake(name: str) -> str:
    """'ConductingEquipment' → 'conducting_equipment'."""
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def _tag_to_attr(tag: str) -> Optional[str]:
    """
    Map an association tag like 'cim:Terminal.ConductingEquipment'
    to a Python attribute name 'conducting_equipment'.
    """
    local = tag.split(":")[-1] if ":" in tag else tag
    if "." in local:
        _, field = local.split(".", 1)
        return _camel_to_snake(field)
    return None


class SAXCIMHandler(xml.sax.handler.ContentHandler):
    """
    SAX ContentHandler for CIM RDF/XML documents.

    Implements a single linear pass over the document, writing parsed
    values directly into CIM objects — no intermediate DOM or triple
    store is ever allocated.  Mirrors Sect. 5.2–5.3 of the paper.

    Lifecycle
    ---------
    startElement  → instantiate class or note current attribute tag
    characters    → buffer character data
    endElement    → dispatch buffered value; close current object
    """

    def __init__(
        self,
        factory: CIMFactory,
        dispatcher: AssignmentDispatcher,
        task_queue: TaskQueue,
    ) -> None:
        super().__init__()
        self._factory = factory
        self._dispatcher = dispatcher
        self._task_queue = task_queue

        # rdf:ID → object (O(1) lookup during task resolution)
        self.registry: Dict[str, BaseClass] = {}

        # Parser state
        self._current_obj: Optional[BaseClass] = None
        self._current_tag: Optional[str] = None
        self._char_buffer: List[str] = []

        # Instrumentation for tests
        self.elements_parsed: int = 0
        self.objects_created: int = 0
        self.attributes_assigned: int = 0

    # ------------------------------------------------------------------
    # SAX callbacks
    # ------------------------------------------------------------------

    def startElement(
        self,
        name: str,
        attrs: xml.sax.xmlreader.AttributesImpl,
    ) -> None:
        self.elements_parsed += 1
        self._char_buffer.clear()

        local = name.split(":")[-1] if ":" in name else name

        # Class-level tag → create and register object
        if self._factory.is_registered(local):
            obj = self._factory.create(local)
            rdf_id = attrs.get("rdf:ID")
            if rdf_id:
                obj.rdf_id = rdf_id
                self.registry[rdf_id] = obj
            self._current_obj = obj
            self.objects_created += 1
            return

        # Attribute/association tag under the current object
        if self._current_obj is not None:
            resource = attrs.get("rdf:resource")
            if resource:
                # Forward-reference association → enqueue task
                target_id = resource.lstrip("#")
                attr = _tag_to_attr(name)
                if attr:
                    self._task_queue.enqueue(
                        Task(self._current_obj, attr, target_id)
                    )
            self._current_tag = name

    def characters(self, content: str) -> None:
        if self._current_tag is not None:
            self._char_buffer.append(content)

    def endElement(self, name: str) -> None:
        # Flush buffered characters to the dispatcher
        if name == self._current_tag and self._current_obj is not None:
            value = "".join(self._char_buffer).strip()
            if value and self._dispatcher.dispatch(self._current_obj, name, value):
                self.attributes_assigned += 1
            self._current_tag = None
            self._char_buffer.clear()

        # Close current object on its closing tag
        local = name.split(":")[-1] if ":" in name else name
        if self._factory.is_registered(local):
            self._current_obj = None


# ---------------------------------------------------------------------------
# 9. CIMDeserializer — public API
# ---------------------------------------------------------------------------

class CIMDeserializer:
    """
    Top-level deserializer combining all CIM++ patterns into one call.

    Usage
    -----
    >>> deserializer = CIMDeserializer()
    >>> registry = deserializer.deserialize(xml_string)
    >>> terminal = registry["BADCAB1E"]
    >>> print(terminal.name)
    'T1'
    """

    def __init__(
        self,
        factory: Optional[CIMFactory] = None,
        dispatcher: Optional[AssignmentDispatcher] = None,
    ) -> None:
        self._factory = factory or build_default_factory()
        self._dispatcher = dispatcher or build_default_dispatcher()

    def deserialize(self, xml_source: str) -> Dict[str, BaseClass]:
        """
        Parse a CIM RDF/XML string via a single SAX pass.

        Forward references are resolved in one post-pass sweep via the
        TaskQueue.  Returns {rdf_id: object} for all instantiated objects.
        """
        task_queue = TaskQueue()
        handler = SAXCIMHandler(self._factory, self._dispatcher, task_queue)
        xml.sax.parseString(xml_source.encode("utf-8"), handler)
        task_queue.resolve_all(handler.registry)
        return handler.registry
