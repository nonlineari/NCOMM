
# M2L Protocol - R Analysis Script
# Generated: 2026-01-18T07:10:32.859844

library(stats)

# Load data
data <- read.csv("/Users/nnlr/projects/NCOMM/m2l_output/m2l_data_20260118_071032.csv")

# Summary statistics
summary_stats <- summary(data)
print("=== Summary Statistics ===")
print(summary_stats)

# Correlation analysis
numeric_cols <- data[, sapply(data, is.numeric)]
correlations <- cor(numeric_cols, use="complete.obs")
print("=== Correlations ===")
print(correlations)

# Time series analysis (if applicable)
if("mean_x" %in% names(data)) {
    # Simple trend analysis
    x_trend <- lm(mean_x ~ seq_along(mean_x), data=data)
    y_trend <- lm(mean_y ~ seq_along(mean_y), data=data)
    
    print("=== X Trend ===")
    print(summary(x_trend))
    print("=== Y Trend ===")
    print(summary(y_trend))
}

# Save results
results <- list(
    summary = summary_stats,
    correlations = correlations,
    n_observations = nrow(data)
)

# Write JSON output
library(jsonlite)
write_json(results, "/Users/nnlr/projects/NCOMM/m2l_output/m2l_analysis_results.json", pretty=TRUE, auto_unbox=TRUE)

print("Analysis complete!")
