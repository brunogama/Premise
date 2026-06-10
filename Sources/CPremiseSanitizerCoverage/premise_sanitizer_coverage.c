#include "premise_sanitizer_coverage.h"
#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>

#define PREMISE_SANCOV_MAX_EDGES 65536u

static _Atomic uint32_t premise_guard_count = 0;
static _Atomic unsigned char premise_edges[PREMISE_SANCOV_MAX_EDGES / 8u];

void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop) {
  if (start == NULL || stop == NULL || start == stop || *start != 0) {
    return;
  }

  for (uint32_t *guard = start; guard < stop; guard++) {
    uint32_t next = atomic_fetch_add_explicit(
      &premise_guard_count,
      1,
      memory_order_relaxed
    ) + 1u;
    *guard = next;
  }
}

void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
  if (guard == NULL || *guard == 0) {
    return;
  }

  uint32_t edge = *guard - 1u;
  if (edge >= PREMISE_SANCOV_MAX_EDGES) {
    return;
  }

  uint32_t byte_index = edge / 8u;
  unsigned char mask = (unsigned char)(1u << (edge % 8u));
  atomic_fetch_or_explicit(&premise_edges[byte_index], mask, memory_order_relaxed);
}

uint32_t premise_sancov_edge_count(void) {
  uint32_t count = atomic_load_explicit(&premise_guard_count, memory_order_relaxed);
  return count > PREMISE_SANCOV_MAX_EDGES ? PREMISE_SANCOV_MAX_EDGES : count;
}

uint32_t premise_sancov_snapshot(uint8_t *buffer, uint32_t buffer_count) {
  if (buffer == NULL || buffer_count == 0) {
    return 0;
  }

  uint32_t edge_count = premise_sancov_edge_count();
  uint32_t needed_bytes = (edge_count + 7u) / 8u;
  uint32_t bytes_to_copy = needed_bytes < buffer_count ? needed_bytes : buffer_count;

  for (uint32_t index = 0; index < bytes_to_copy; index++) {
    buffer[index] = atomic_load_explicit(&premise_edges[index], memory_order_relaxed);
  }

  return bytes_to_copy;
}

void premise_sancov_reset(void) {
  for (uint32_t index = 0; index < PREMISE_SANCOV_MAX_EDGES / 8u; index++) {
    atomic_store_explicit(&premise_edges[index], 0, memory_order_relaxed);
  }
}
