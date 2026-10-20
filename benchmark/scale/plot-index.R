#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
stopifnot(length(args) == 2L)
x <- read.csv(args[1])
x <- x[x$H == 1000000, ]
png(args[2], width = 1400, height = 620, res = 150)
par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1))
colors <- c(before = "#555555", after = "#126B9B")
plot(
  range(x$U),
  range(x$kernel_seconds),
  type = "n",
  log = "xy",
  xlab = "Distinct keys U (1 million rows)",
  ylab = "Kernel elapsed seconds",
  main = "Canonical work-unit construction"
)
for (m in c("before", "after")) {
  v <- x[x$mode == m, ]
  lines(v$U, v$kernel_seconds, col = colors[m], type = "b", pch = 19, lwd = 2)
}
legend(
  "topleft",
  legend = c("Repeated scans", "Single row index"),
  col = colors,
  lty = 1,
  pch = 19,
  bty = "n"
)
plot(
  range(x$U),
  range(x$kernel_highwater_rss_bytes / 1024^2),
  type = "n",
  log = "x",
  xlab = "Distinct keys U (1 million rows)",
  ylab = "Whole-process high-water RSS (MiB)",
  main = "Measured process memory"
)
for (m in c("before", "after")) {
  v <- x[x$mode == m, ]
  lines(
    v$U,
    v$kernel_highwater_rss_bytes / 1024^2,
    col = colors[m],
    type = "b",
    pch = 19,
    lwd = 2
  )
}
mtext(
  "One observation per point; synthetic index; identical unit SHA256; no full-screen scientific qualification",
  outer = TRUE,
  side = 1,
  line = -1,
  cex = .65
)
dev.off()
