#pragma once
#include "amount_value.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

class FoundationAmount : public godot::RefCounted {
    GDCLASS(FoundationAmount, godot::RefCounted)
    using Value = foundation::Amount;
    using Dictionary = godot::Dictionary;
    using String = godot::String;
    using Variant = godot::Variant;
    static std::string text(const String &s) { return s.utf8().get_data(); }
    static int64_t integer(const Variant &v) {
        if (v.get_type() != Variant::STRING) throw std::domain_error("AmountIntegerEncoding");
        std::string s = text(v); size_t used = 0; int64_t n;
        try { n = std::stoll(s, &used); } catch (...) { throw std::domain_error("AmountIntegerEncoding"); }
        if (used != s.size() || std::to_string(n) != s) throw std::domain_error("AmountIntegerEncoding");
        return n;
    }
    static double scalar(const Variant &v) {
        if (v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT)
            throw std::domain_error("AmountScalarType");
        double x = v;
        if (!std::isfinite(x)) throw std::domain_error("AmountScalarType");
        return x;
    }
    static Dictionary encode(const Value &v) {
        Dictionary d; d["m"] = String(v.mantissa_text().c_str());
        d["e"] = String(std::to_string(v.exponent()).c_str()); d.make_read_only(); return d;
    }
    static Value decode(const Variant &v) {
        if (v.get_type() != Variant::DICTIONARY) throw std::domain_error("AmountEncoding");
        Dictionary d = v;
        if (d.size() != 2 || !d.has("m") || !d.has("e") ||
            d["m"].get_type() != Variant::STRING) throw std::domain_error("AmountEncoding");
        int64_t e = integer(d["e"]);
        Value a = Value::decimal(text(d["m"]) + "e" + std::to_string(e));
        Dictionary canonical = encode(a);
        if (canonical["m"] != d["m"] || canonical["e"] != d["e"])
            throw std::domain_error("AmountEncoding");
        return a;
    }
    // Sum ceil(base * rate^i) over a contiguous exponent range. Equal integer
    // terms are grouped; beyond Amount's ordinary precision use a geometric sum.
    static Value sum_ceiled_geometric(Value base, double rate, int64_t start, int64_t count, bool &extreme) {
        if (rate < 1 || start < 0 || count < 0 || start > INT64_MAX - count)
            throw std::domain_error("AmountSeriesRange");
        if (!count) return {};
        auto unit = [&](int64_t exponent) {
            return base.multiply(Value::normalized(rate).power(double(exponent))).ceil_value();
        };
        const Value threshold = Value::decimal("1e15");
        if (rate == 1) {
            Value total = unit(start).multiply(Value::decimal(std::to_string(count)));
            extreme = total.compare(threshold) >= 0; return total;
        }
        Value total;
        int64_t at = start, last = start + count - 1;
        while (at <= last) {
            Value term = unit(at);
            if (term.compare(threshold) >= 0) { extreme = true; break; }
            int64_t lo = at, hi = last;
            while (lo < hi) {
                int64_t mid = lo + (hi - lo) / 2 + 1;
                if (unit(mid).compare(term) == 0) lo = mid; else hi = mid - 1;
            }
            total = total.add(term.multiply(Value::decimal(std::to_string(lo - at + 1))));
            if (total.compare(threshold) >= 0) { extreme = true; break; }
            if (lo == last) return total;
            at = lo + 1;
        }
        Value raw = base.multiply(Value::normalized(rate).power(double(start))).multiply(Value::geometric(rate, count));
        return (raw.compare(threshold) < 0 ? threshold : raw).ceil_value();
    }
protected:
    static void _bind_methods() {
        godot::ClassDB::bind_method(godot::D_METHOD("apply", "operation", "operands"), &FoundationAmount::apply);
    }
public:
    Dictionary apply(const String &operation, const godot::Array &operands) const {
        Dictionary result;
        try {
            const std::string op = text(operation);
            auto require = [&](int n) { if (operands.size() != n) throw std::domain_error("AmountArity"); };
            Value value;
            if (op == "zero") require(0);
            else if (op == "from_decimal") {
                require(1);
                if (operands[0].get_type() != Variant::STRING) throw std::domain_error("AmountDecimalType");
                value = Value::decimal(text(operands[0]));
            } else if (op == "normalize") {
                require(2); value = Value::normalized(scalar(operands[0]), integer(operands[1]));
            } else if (op == "sum_geometric") {
                require(2); value = Value::geometric(scalar(operands[0]), integer(operands[1]));
            } else if (op == "sum_ceiled_geometric") {
                require(4);
                bool extreme = false;
                value = sum_ceiled_geometric(decode(operands[0]), scalar(operands[1]), integer(operands[2]), integer(operands[3]), extreme);
                result["extreme"] = extreme;
            } else {
                if (op != "add" && op != "sub_nonnegative" && op != "mul" && op != "div" && op != "pow" && op != "compare" && op != "min" && op != "max" && op != "round_significant" && op != "to_ratio" && op != "floor" && op != "ceil" && op != "decode" && op != "encode" && op != "log10" && op != "to_display") throw std::domain_error("AmountOperation");
                int arity = (op == "add" || op == "sub_nonnegative" || op == "mul" || op == "div" ||
                    op == "pow" || op == "compare" || op == "min" || op == "max" ||
                    op == "round_significant" || op == "to_ratio") ? 2 : 1;
                require(arity); Value a = decode(operands[0]);
                if (op == "pow") value = a.power(scalar(operands[1]));
                else if (op == "round_significant") {
                    int64_t n = integer(operands[1]);
                    if (n < 1 || n > 15) throw std::domain_error("AmountPrecision");
                    value = a.rounded(int(n));
                } else if (op == "floor") value = a.floor_value();
                else if (op == "ceil") value = a.ceil_value();
                else if (op == "decode" || op == "encode") value = a;
                else if (op == "log10") result["scalar"] = double(a.logarithm());
                else if (op == "to_display") result["text"] = String((a.mantissa_text() + "e" + std::to_string(a.exponent())).c_str());
                else {
                    Value b = decode(operands[1]);
                    if (op == "add") value = a.add(b);
                    else if (op == "sub_nonnegative") value = a.subtract(b);
                    else if (op == "mul") value = a.multiply(b);
                    else if (op == "div") value = a.divide(b);
                    else if (op == "compare") result["scalar"] = a.compare(b);
                    else if (op == "min") value = a.compare(b) <= 0 ? a : b;
                    else if (op == "max") value = a.compare(b) >= 0 ? a : b;
                    else if (op == "to_ratio") result["scalar"] = a.ratio(b);
                    else throw std::domain_error("AmountOperation");
                }
            }
            if (!result.has("scalar") && !result.has("text")) result["value"] = encode(value);
            result["ok"] = true;
        } catch (const std::exception &e) { result.clear(); result["ok"] = false; result["error"] = String(e.what()); }
        return result;
    }
};
