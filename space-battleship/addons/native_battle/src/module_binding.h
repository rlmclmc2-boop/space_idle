#pragma once
#include "module_evaluation.h"

class SpaceModuleEvaluator : public RefCounted {
    GDCLASS(SpaceModuleEvaluator, RefCounted)
    static int64_t integer(const Dictionary &input, const String &key) {
        if (!input.has(key) || input[key].get_type() != Variant::STRING)
            throw std::domain_error("InvalidModuleInteger");
        String encoded = input[key];
        if (!encoded.is_valid_int()) throw std::domain_error("InvalidModuleInteger");
        int64_t value = encoded.to_int();
        if (String::num_int64(value) != encoded) throw std::domain_error("InvalidModuleInteger");
        return value;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("evaluate", "input"), &SpaceModuleEvaluator::evaluate);
        ClassDB::bind_method(D_METHOD("growth", "input"), &SpaceModuleEvaluator::growth);
    }
public:
    Dictionary growth(const Dictionary &input) const {
        Dictionary result;
        try {
            if(!input.has("base") || input["base"].get_type()!=Variant::DICTIONARY || !input.has("growth") ||
                (input["growth"].get_type()!=Variant::INT && input["growth"].get_type()!=Variant::FLOAT)) throw std::domain_error("InvalidEquipmentGrowth");
            auto value=space::equipment_growth(SpaceAmount::read(input["base"]),double(input["growth"]),integer(input,"level"));
            result["value"]=SpaceAmount::encode(value);result["ok"]=true;
        } catch(const std::exception &error) {result["ok"]=false;result["error"]=String(error.what());}
        return result;
    }
    Dictionary evaluate(const Dictionary &input) const {
        Dictionary result;
        try {
            if (!input.has("charged_base") || input["charged_base"].get_type() != Variant::DICTIONARY)
                throw std::domain_error("InvalidModuleInput");
            space::ModuleInput values;
            values.charged_base = SpaceAmount::read(input["charged_base"]);
            values.history_count = integer(input,"history_count");
            values.effective_level = integer(input,"effective_level");
            for (const char *key : {"growth","log_base","round_scale"}) {
                if (!input.has(key) || (input[key].get_type() != Variant::INT && input[key].get_type() != Variant::FLOAT))
                    throw std::domain_error("InvalidModuleInput");
            }
            values.growth = input["growth"]; values.log_base = input["log_base"]; values.round_scale = input["round_scale"];
            for (const char *key : {"branch_factors","external_factors"}) {
                if (!input.has(key) || input[key].get_type() != Variant::ARRAY) throw std::domain_error("InvalidModuleFactors");
                Array factors = input[key];
                auto &target = String(key) == String("branch_factors") ? values.branch_factors : values.external_factors;
                for (int i=0;i<factors.size();++i) {
                    if (factors[i].get_type() != Variant::DICTIONARY) throw std::domain_error("InvalidModuleFactors");
                    target.push_back(SpaceAmount::read(factors[i]));
                }
            }
            auto output = space::evaluate_module(values);
            result["charged_base"] = SpaceAmount::encode(output.charged_base);
            result["history_factor"] = SpaceAmount::encode(output.history_factor);
            result["history_enhanced"] = SpaceAmount::encode(output.history_enhanced);
            result["branched"] = SpaceAmount::encode(output.branched);
            result["final"] = SpaceAmount::encode(output.final);
            result["history_count"] = input["history_count"];
            result["ok"] = true;
        } catch (const std::exception &error) { result["ok"] = false; result["error"] = String(error.what()); }
        return result;
    }
};
