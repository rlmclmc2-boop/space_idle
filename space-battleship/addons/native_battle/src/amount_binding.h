#pragma once
#include "amount.h"

class SpaceAmount : public RefCounted {
    GDCLASS(SpaceAmount, RefCounted)
    static space::Amount read(const Dictionary &value) {
        if (!value.has("m") || !value.has("e") || value["m"].get_type() != Variant::STRING || value["e"].get_type() != Variant::STRING)
            throw std::domain_error("InvalidAmountEncoding");
        return space::Amount::decode(String(value["m"]).utf8().get_data(), String(value["e"]).utf8().get_data());
    }
    static Dictionary encode(const space::Amount &value) {
        Dictionary result; result["m"] = String(value.mantissa_text().c_str()); result["e"] = String(std::to_string(value.e).c_str()); return result;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("calculate", "operation", "left", "right", "parameter", "count"), &SpaceAmount::calculate,
            DEFVAL(Dictionary()), DEFVAL(Dictionary()), DEFVAL(0.0), DEFVAL(int64_t(0)));
    }
public:
    Dictionary calculate(const String &operation, const Dictionary &left, const Dictionary &right, double parameter, int64_t count) const {
        Dictionary result;
        try {
            std::string op = operation.utf8().get_data();
            space::Amount a, b, value;
            if (op == "from_decimal") value = space::Amount::from_decimal(String(left.get("text", "")).utf8().get_data());
            else if (op == "zero") value = {};
            else {
                a = read(left);
                if (op == "add" || op == "sub_nonnegative" || op == "mul" || op == "div" || op == "compare" || op == "min" || op == "max" || op == "to_ratio") b = read(right);
                if (op == "add") value = a.add(b);
                else if (op == "sub_nonnegative") value = a.sub_nonnegative(b);
                else if (op == "mul") value = a.mul(b);
                else if (op == "div") value = a.div(b);
                else if (op == "pow") value = a.pow(parameter);
                else if (op == "floor") value = a.floor();
                else if (op == "ceil") value = a.ceil();
                else if (op == "round_significant") value = a.round_significant(int(count));
                else if (op == "sum_geometric") value = space::Amount::sum_geometric(a, parameter, count);
                else if (op == "min") value = space::Amount::min(a,b);
                else if (op == "max") value = space::Amount::max(a,b);
                else if (op == "compare") result["scalar"] = a.compare(b);
                else if (op == "log10") result["scalar"] = a.log10();
                else if (op == "to_ratio") result["scalar"] = a.to_ratio(b);
                else if (op == "to_display") result["text"] = String(a.to_display().c_str());
                else if (op == "normalize" || op == "encode" || op == "decode") value = a;
                else throw std::domain_error("UnknownAmountOperation");
            }
            if (!result.has("scalar") && !result.has("text")) result["value"] = encode(value);
            result["ok"] = true;
        } catch (const std::exception &error) { result["ok"] = false; result["error"] = String(error.what()); }
        return result;
    }
};
