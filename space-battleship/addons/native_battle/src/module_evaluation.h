#pragma once
#include "amount.h"
#include <vector>

namespace space {
inline Amount equipment_growth(const Amount &base, double growth, int64_t level) {
    if(level<1 || !std::isfinite(growth) || growth<0) throw std::domain_error("InvalidEquipmentGrowth");
    if(level==1) return base;
    Amount raw=base.mul(Amount(1+growth).pow(double(level-1)));
    return raw.compare(Amount(100))<0 ? raw.div(Amount(10)).floor().mul(Amount(10)).add(Amount(5)) : raw.round_significant(2);
}
struct ModuleInput {
    Amount charged_base;
    int64_t history_count = 0;
    int64_t effective_level = 0;
    double growth = 0, log_base = 10, round_scale = 10;
    std::vector<Amount> branch_factors, external_factors;
};
struct ModuleEvaluation {
    Amount charged_base, history_factor, history_enhanced, branched, final;
};

// Shared by previews and attack/defence evaluation. All unbounded products use
// Amount. The integer history is never stored or returned through a double.
inline ModuleEvaluation evaluate_module(const ModuleInput &input) {
    if (input.history_count < 0 || input.effective_level < 0 || !std::isfinite(input.growth) || input.growth < 0 ||
        !std::isfinite(input.log_base) || input.log_base <= 1 || !std::isfinite(input.round_scale) || input.round_scale <= 0)
        throw std::domain_error("InvalidModuleInput");
    ModuleEvaluation output;
    output.charged_base = input.charged_base;
    Amount bonus;
    if (input.history_count > 1 && input.effective_level > 0 && input.growth > 0) {
        long double logarithm = std::log(static_cast<long double>(input.history_count)) / std::log(static_cast<long double>(input.log_base));
        bonus = Amount(input.growth).mul(Amount::from_decimal(std::to_string(input.effective_level)))
            .mul(Amount(double(logarithm))).mul(Amount(input.round_scale)).add(Amount(0.5)).floor().div(Amount(input.round_scale));
    }
    output.history_factor = Amount(1).add(bonus);
    output.history_enhanced = input.charged_base.mul(output.history_factor).ceil();
    output.branched = output.history_enhanced;
    for (const Amount &factor : input.branch_factors) output.branched = output.branched.mul(factor);
    output.final = output.branched;
    for (const Amount &factor : input.external_factors) output.final = output.final.mul(factor);
    return output;
}
}

