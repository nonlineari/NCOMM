#!/usr/bin/env Rscript
# M2L Protocol - Data Visualization Script
# Generates comprehensive visualizations from simulation data

library(stats)
library(graphics)

# Configuration
data_file <- "m2l_output/m2l_data_20260118_071032.csv"
output_dir <- "m2l_output"

cat("==========================================================\n")
cat("M2L PROTOCOL - R VISUALIZATION\n")
cat("==========================================================\n")
cat("Reading data from:", data_file, "\n")

# Load data
data <- read.csv(data_file)
cat("Loaded", nrow(data), "observations\n")
cat("Columns:", paste(names(data), collapse=", "), "\n")

# Summary statistics
cat("\n--- Summary Statistics ---\n")
print(summary(data[, sapply(data, is.numeric)]))

# ============================================================
# VISUALIZATION 1: Time Series Plot
# ============================================================
png(file.path(output_dir, "m2l_timeseries.png"), 
    width=1200, height=800, res=120)

par(mfrow=c(2,2), mar=c(4,4,3,2))

# Mean X over time
plot(data$mean_x, type="l", lwd=2, col="blue",
     main="Mean X Coordinate Evolution",
     xlab="Scan Number", ylab="Mean X",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")
points(data$mean_x, pch=19, col=rgb(0,0,1,0.5), cex=0.8)

# Mean Y over time
plot(data$mean_y, type="l", lwd=2, col="red",
     main="Mean Y Coordinate Evolution",
     xlab="Scan Number", ylab="Mean Y",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")
points(data$mean_y, pch=19, col=rgb(1,0,0,0.5), cex=0.8)

# Standard deviations
plot(data$std_x, type="l", lwd=2, col="darkblue",
     main="Standard Deviation X",
     xlab="Scan Number", ylab="Std Dev X",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")

plot(data$std_y, type="l", lwd=2, col="darkred",
     main="Standard Deviation Y",
     xlab="Scan Number", ylab="Std Dev Y",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")

dev.off()
cat("\n✓ Generated: m2l_timeseries.png\n")

# ============================================================
# VISUALIZATION 2: Phase Space Analysis
# ============================================================
png(file.path(output_dir, "m2l_phasespace.png"), 
    width=1200, height=800, res=120)

par(mfrow=c(2,2), mar=c(4,4,3,2))

# Mean X vs Mean Y trajectory
plot(data$mean_x, data$mean_y, type="b", lwd=2, col="purple",
     main="Phase Space Trajectory (Mean X vs Mean Y)",
     xlab="Mean X", ylab="Mean Y",
     cex.main=1.3, cex.lab=1.1, pch=19)
grid(col="gray80")
# Add start and end markers
points(data$mean_x[1], data$mean_y[1], pch=15, col="green", cex=2)
points(data$mean_x[nrow(data)], data$mean_y[nrow(data)], pch=17, col="red", cex=2)
legend("topright", legend=c("Start", "End"), 
       pch=c(15,17), col=c("green","red"), cex=0.8)

# X range over time
plot(1:nrow(data), data$max_x - data$min_x, type="l", lwd=2, col="darkgreen",
     main="X Coordinate Range",
     xlab="Scan Number", ylab="Range (Max - Min)",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")

# Y range over time
plot(1:nrow(data), data$max_y - data$min_y, type="l", lwd=2, col="darkorange",
     main="Y Coordinate Range",
     xlab="Scan Number", ylab="Range (Max - Min)",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")

# Ratio plot
x_range <- data$max_x - data$min_x
y_range <- data$max_y - data$min_y
ratio <- x_range / (y_range + 1e-10)
plot(ratio, type="l", lwd=2, col="brown",
     main="X/Y Range Ratio",
     xlab="Scan Number", ylab="Ratio",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")
abline(h=1, lty=2, col="gray50")

dev.off()
cat("✓ Generated: m2l_phasespace.png\n")

# ============================================================
# VISUALIZATION 3: Network Topology Metrics
# ============================================================
png(file.path(output_dir, "m2l_topology.png"), 
    width=1200, height=800, res=120)

par(mfrow=c(2,2), mar=c(4,4,3,2))

# Phase space density
plot(data$phase_space_density, type="l", lwd=2, col="darkviolet",
     main="Phase Space Density",
     xlab="Scan Number", ylab="Density",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")
points(data$phase_space_density, pch=19, col=rgb(0.5,0,0.5,0.5))

# Clustering coefficient
plot(data$clustering_coefficient, type="l", lwd=2, col="steelblue",
     main="Clustering Coefficient",
     xlab="Scan Number", ylab="Coefficient",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")
points(data$clustering_coefficient, pch=19, col=rgb(0,0.5,0.8,0.5))

# Density vs Clustering
plot(data$phase_space_density, data$clustering_coefficient, 
     pch=19, col="forestgreen", cex=1.5,
     main="Density vs Clustering",
     xlab="Phase Space Density", ylab="Clustering Coefficient",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")
# Add scan number labels
text(data$phase_space_density, data$clustering_coefficient, 
     labels=1:nrow(data), cex=0.6, pos=3)

# Combined metric (density * clustering)
combined <- data$phase_space_density * data$clustering_coefficient
plot(combined, type="l", lwd=2, col="firebrick",
     main="Network Cohesion (Density × Clustering)",
     xlab="Scan Number", ylab="Cohesion",
     cex.main=1.3, cex.lab=1.1)
grid(col="gray80")
points(combined, pch=19, col=rgb(0.8,0,0,0.5))

dev.off()
cat("✓ Generated: m2l_topology.png\n")

# ============================================================
# VISUALIZATION 4: Statistical Distribution
# ============================================================
png(file.path(output_dir, "m2l_distributions.png"), 
    width=1200, height=800, res=120)

par(mfrow=c(2,3), mar=c(4,4,3,2))

# Histogram of mean X
hist(data$mean_x, breaks=10, col="lightblue", border="darkblue",
     main="Distribution of Mean X",
     xlab="Mean X", ylab="Frequency",
     cex.main=1.2, cex.lab=1.0)

# Histogram of mean Y
hist(data$mean_y, breaks=10, col="lightcoral", border="darkred",
     main="Distribution of Mean Y",
     xlab="Mean Y", ylab="Frequency",
     cex.main=1.2, cex.lab=1.0)

# Boxplot comparison
boxplot(data$mean_x, data$mean_y,
        names=c("Mean X", "Mean Y"),
        col=c("lightblue", "lightcoral"),
        main="Coordinate Distributions",
        ylab="Value",
        cex.main=1.2)

# QQ plot for mean X
qqnorm(data$mean_x, main="Q-Q Plot: Mean X", 
       pch=19, col="blue", cex=0.8)
qqline(data$mean_x, col="red", lwd=2)

# QQ plot for mean Y
qqnorm(data$mean_y, main="Q-Q Plot: Mean Y", 
       pch=19, col="red", cex=0.8)
qqline(data$mean_y, col="blue", lwd=2)

# Scatter with density
smoothScatter(data$mean_x, data$mean_y, 
              main="Density Scatter",
              xlab="Mean X", ylab="Mean Y",
              cex.main=1.2)

dev.off()
cat("✓ Generated: m2l_distributions.png\n")

# ============================================================
# VISUALIZATION 5: Comprehensive Summary Dashboard
# ============================================================
png(file.path(output_dir, "m2l_dashboard.png"), 
    width=1600, height=1200, res=120)

layout(matrix(c(1,2,3,4,5,6,7,8,9), nrow=3, byrow=TRUE))
par(mar=c(3,3,2,1), mgp=c(2,0.7,0))

# 1. Main trajectory
plot(data$mean_x, data$mean_y, type="b", lwd=2, col="purple",
     main="1. Phase Space Trajectory", xlab="Mean X", ylab="Mean Y", pch=19)
points(data$mean_x[1], data$mean_y[1], pch=15, col="green", cex=2)
points(data$mean_x[nrow(data)], data$mean_y[nrow(data)], pch=17, col="red", cex=2)
grid(col="gray80")

# 2. X evolution
plot(data$mean_x, type="l", lwd=2, col="blue",
     main="2. Mean X Evolution", xlab="Scan", ylab="Mean X")
grid(col="gray80")

# 3. Y evolution
plot(data$mean_y, type="l", lwd=2, col="red",
     main="3. Mean Y Evolution", xlab="Scan", ylab="Mean Y")
grid(col="gray80")

# 4. Std X
plot(data$std_x, type="l", lwd=2, col="darkblue",
     main="4. Std Dev X", xlab="Scan", ylab="Std X")
grid(col="gray80")

# 5. Std Y
plot(data$std_y, type="l", lwd=2, col="darkred",
     main="5. Std Dev Y", xlab="Scan", ylab="Std Y")
grid(col="gray80")

# 6. Density
plot(data$phase_space_density, type="l", lwd=2, col="darkviolet",
     main="6. Phase Space Density", xlab="Scan", ylab="Density")
grid(col="gray80")

# 7. Clustering
plot(data$clustering_coefficient, type="l", lwd=2, col="steelblue",
     main="7. Clustering Coefficient", xlab="Scan", ylab="Coefficient")
grid(col="gray80")

# 8. X range
plot(data$max_x - data$min_x, type="l", lwd=2, col="darkgreen",
     main="8. X Range", xlab="Scan", ylab="Range")
grid(col="gray80")

# 9. Y range
plot(data$max_y - data$min_y, type="l", lwd=2, col="darkorange",
     main="9. Y Range", xlab="Scan", ylab="Range")
grid(col="gray80")

dev.off()
cat("✓ Generated: m2l_dashboard.png\n")

# ============================================================
# STATISTICAL ANALYSIS REPORT
# ============================================================
cat("\n==========================================================\n")
cat("STATISTICAL ANALYSIS\n")
cat("==========================================================\n")

# Correlations
numeric_cols <- data[, sapply(data, is.numeric)]
cor_matrix <- cor(numeric_cols, use="complete.obs")
cat("\n--- Correlation Matrix (top correlations) ---\n")

# Find strongest correlations
cor_pairs <- which(abs(cor_matrix) > 0.7 & cor_matrix != 1, arr.ind=TRUE)
if(nrow(cor_pairs) > 0) {
    for(i in 1:nrow(cor_pairs)) {
        row_idx <- cor_pairs[i,1]
        col_idx <- cor_pairs[i,2]
        if(row_idx < col_idx) {  # Avoid duplicates
            cat(sprintf("%s <-> %s: %.3f\n", 
                       colnames(cor_matrix)[row_idx],
                       colnames(cor_matrix)[col_idx],
                       cor_matrix[row_idx, col_idx]))
        }
    }
} else {
    cat("No strong correlations (>0.7) found\n")
}

# Trend analysis
cat("\n--- Trend Analysis ---\n")
x_trend <- lm(mean_x ~ seq_along(mean_x), data=data)
y_trend <- lm(mean_y ~ seq_along(mean_y), data=data)

cat(sprintf("Mean X trend: slope = %.4f (p = %.4f)\n", 
           coef(x_trend)[2], 
           summary(x_trend)$coefficients[2,4]))
cat(sprintf("Mean Y trend: slope = %.4f (p = %.4f)\n", 
           coef(y_trend)[2], 
           summary(y_trend)$coefficients[2,4]))

# Network metrics
cat("\n--- Network Metrics ---\n")
cat(sprintf("Average density: %.4f\n", mean(data$phase_space_density)))
cat(sprintf("Average clustering: %.4f\n", mean(data$clustering_coefficient)))
cat(sprintf("Density range: [%.4f, %.4f]\n", 
           min(data$phase_space_density), 
           max(data$phase_space_density)))
cat(sprintf("Clustering range: [%.4f, %.4f]\n", 
           min(data$clustering_coefficient), 
           max(data$clustering_coefficient)))

cat("\n==========================================================\n")
cat("VISUALIZATION COMPLETE\n")
cat("==========================================================\n")
cat("Output directory:", output_dir, "\n")
cat("Generated files:\n")
cat("  - m2l_timeseries.png\n")
cat("  - m2l_phasespace.png\n")
cat("  - m2l_topology.png\n")
cat("  - m2l_distributions.png\n")
cat("  - m2l_dashboard.png\n")
cat("==========================================================\n")
