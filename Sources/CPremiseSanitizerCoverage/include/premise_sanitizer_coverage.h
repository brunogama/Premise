#ifndef PREMISE_SANITIZER_COVERAGE_H
#define PREMISE_SANITIZER_COVERAGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t premise_sancov_edge_count(void);
uint32_t premise_sancov_snapshot(uint8_t *buffer, uint32_t buffer_count);
void premise_sancov_reset(void);

#ifdef __cplusplus
}
#endif

#endif
