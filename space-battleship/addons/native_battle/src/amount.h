#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <limits>
#include <regex>
#include <sstream>
#include <stdexcept>
#include <string>

namespace space {
// The only numeric implementation. Native callers hold values; the Godot API
// transports the same canonical encoding, never a second arithmetic model.
struct Amount {
    static constexpr int64_t limit = 9000000000000000LL;
    double m = 0;
    int64_t e = 0;
    Amount() = default;
    Amount(double mantissa, int64_t exponent = 0) { normalize(mantissa, exponent); }
    void normalize(double mantissa, int64_t exponent) {
        if (!std::isfinite(mantissa) || mantissa < 0) throw std::domain_error("InvalidAmount");
        if (mantissa == 0) { m = 0; e = 0; return; }
        auto shift = static_cast<int64_t>(std::floor(std::log10(mantissa)));
        // pow(10,-324) underflows for subnormal input. Scale in two pieces.
        double scaled = shift < -300 ? mantissa * 1e300 / std::pow(10.0, double(shift + 300))
                                    : mantissa / std::pow(10.0, double(shift));
        exponent += shift;
        while (scaled < 1) { scaled *= 10; --exponent; }
        while (scaled >= 10) { scaled /= 10; ++exponent; }
        scaled = std::round(scaled * 1e14) / 1e14;
        if (scaled >= 10) { scaled = 1; ++exponent; }
        if (exponent > limit) throw std::overflow_error("AmountRangeExceeded");
        if (exponent < -limit) { m = 0; e = 0; return; }
        m = scaled; e = exponent;
    }
    static Amount from_decimal(const std::string &text) {
        static const std::regex pattern(R"(^\+?([0-9]+)(?:\.([0-9]*))?(?:[eE]([+-]?[0-9]+))?$)");
        std::smatch parts;
        if (!std::regex_match(text, parts, pattern)) throw std::domain_error("InvalidAmount");
        std::string digits = parts[1].str() + parts[2].str();
        const auto first = digits.find_first_not_of('0');
        int64_t exponent = 0;
        if (parts[3].matched) {
            try { exponent = std::stoll(parts[3].str()); }
            catch (...) { throw std::overflow_error("AmountRangeExceeded"); }
            if (exponent > limit + 100000 || exponent < -limit - 100000)
                throw std::overflow_error("AmountRangeExceeded");
        }
        if (first == std::string::npos) return {};
        exponent += static_cast<int64_t>(parts[1].length()) - static_cast<int64_t>(first) - 1;
        std::string significant = digits.substr(first, 17);
        significant.insert(1, ".");
        return Amount(std::stod(significant), exponent);
    }
    static Amount decode(const std::string &mantissa, const std::string &exponent) {
        static const std::regex integer(R"(^(0|-?[1-9][0-9]*)$)");
        static const std::regex decimal(R"(^(0|[1-9](\.[0-9]+)?)$)");
        if (!std::regex_match(exponent, integer) || !std::regex_match(mantissa, decimal))
            throw std::domain_error("InvalidAmountEncoding");
        int64_t exp;
        try { exp = std::stoll(exponent); } catch (...) { throw std::overflow_error("AmountRangeExceeded"); }
        double value = std::stod(mantissa);
        if (exp < -limit || exp > limit || (value == 0 ? exp != 0 : value < 1 || value >= 10))
            throw std::domain_error("InvalidAmountEncoding");
        Amount result(value, exp);
        if (result.mantissa_text() != mantissa || result.e != exp)
            throw std::domain_error("NoncanonicalAmount");
        return result;
    }
    std::string mantissa_text() const {
        std::ostringstream out; out << std::setprecision(15) << m; return out.str();
    }
    std::string to_display() const { return m == 0 ? "0" : mantissa_text() + "e" + std::to_string(e); }
    int compare(const Amount &b) const {
        if (m == 0 || b.m == 0) return (m > 0) - (b.m > 0);
        if (e != b.e) return (e > b.e) ? 1 : -1;
        return (m > b.m) - (m < b.m);
    }
    Amount add(const Amount &b) const {
        if (m == 0) return b;
        if (b.m == 0) return *this;
        if (e < b.e) return b.add(*this);
        const int64_t gap = e - b.e;
        return gap > 16 ? *this : Amount(m + b.m * std::pow(10.0, -double(gap)), e);
    }
    Amount sub_nonnegative(const Amount &b) const {
        if (compare(b) <= 0) return {};
        if (b.m == 0 || e - b.e > 16) return *this;
        return Amount(std::max(0.0, m - b.m * std::pow(10.0, double(b.e - e))), e);
    }
    Amount mul(const Amount &b) const { return m == 0 || b.m == 0 ? Amount() : Amount(m * b.m, e + b.e); }
    Amount div(const Amount &b) const {
        if (b.m == 0) throw std::domain_error("AmountDivisionByZero");
        return m == 0 ? Amount() : Amount(m / b.m, e - b.e);
    }
    double log10() const {
        if (m == 0) throw std::domain_error("AmountLogZero");
        return double(e) + std::log10(m);
    }
    Amount pow(double power) const {
        if (!std::isfinite(power)) throw std::domain_error("InvalidAmountPower");
        if (power == 0) return Amount(1);
        if (m == 0) { if (power < 0) throw std::domain_error("AmountDivisionByZero"); return {}; }
        // long double keeps the fractional exponent on platforms that support
        // wider precision; checked before conversion to the int64 exponent.
        long double logarithm = (static_cast<long double>(e) + std::log10(static_cast<long double>(m))) * power;
        if (std::floor(logarithm) > limit) throw std::overflow_error("AmountRangeExceeded");
        if (logarithm < -limit) return {};
        auto exponent = static_cast<int64_t>(std::floor(logarithm));
        return Amount(double(std::pow(10.0L, logarithm - exponent)), exponent);
    }
    Amount floor() const {
        if (m == 0 || e < 0) return {};
        if (e >= 15) return *this;
        return Amount(std::floor(m * std::pow(10.0, double(e))));
    }
    Amount ceil() const {
        if (m == 0 || e >= 15) return *this;
        if (e < 0) return Amount(1);
        return Amount(std::ceil(m * std::pow(10.0, double(e))));
    }
    Amount round_significant(int digits) const {
        if (digits < 1 || digits > 15) throw std::domain_error("InvalidAmountPrecision");
        double scale = std::pow(10.0, digits - 1);
        return Amount(std::round(m * scale) / scale, e);
    }
    static Amount min(const Amount &a, const Amount &b) { return a.compare(b) <= 0 ? a : b; }
    static Amount max(const Amount &a, const Amount &b) { return a.compare(b) >= 0 ? a : b; }
    static Amount sum_geometric(const Amount &first, double ratio, int64_t count) {
        if (count < 0 || !std::isfinite(ratio) || ratio <= 0) throw std::domain_error("InvalidGeometricSum");
        if (!count || first.m == 0) return {};
        if (ratio == 1) return first.mul(from_decimal(std::to_string(count)));
        long double log_r = std::log1p(static_cast<long double>(ratio) - 1);
        long double x = static_cast<long double>(count) * log_r;
        if (x < 600) return first.mul(Amount(double(std::expm1(x) / std::expm1(log_r))));
        long double log_sum = x / std::log(10.0L) - std::log10(std::expm1(log_r));
        if (std::floor(log_sum) > limit) throw std::overflow_error("AmountRangeExceeded");
        auto exponent = static_cast<int64_t>(std::floor(log_sum));
        return first.mul(Amount(double(std::pow(10.0L, log_sum - exponent)), exponent));
    }
    double to_ratio(const Amount &denominator) const {
        if (denominator.m == 0) throw std::domain_error("AmountDivisionByZero");
        if (compare(denominator) >= 0) return 1;
        int64_t gap = e - denominator.e;
        return m == 0 || gap < -324 ? 0 : std::clamp(m / denominator.m * std::pow(10.0, double(gap)), 0.0, 1.0);
    }
};
}
