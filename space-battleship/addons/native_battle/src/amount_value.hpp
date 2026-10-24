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

namespace foundation {
// All magnitudes, including ordinary values, use this one representation.
class Amount {
    double coefficient_ = 0;
    int64_t power_ = 0;
    static constexpr int64_t limit = 9000000000000000LL;
    static double significant(double x, int digits) {
        if (x == 0) return 0;
        long double scale = std::pow(10.L, digits - 1 - int(std::floor(std::log10(x))));
        return double(std::floor(static_cast<long double>(x) * scale + 0.5L) / scale);
    }
    int64_t decimal_significand() const {
        return std::llround(coefficient_ * 1e14);
    }
    int64_t integer_unit() const {
        int64_t unit = 1;
        for (int64_t i = power_; i < 14; ++i) unit *= 10;
        return unit;
    }
public:
    Amount() = default;
    static Amount normalized(double m, int64_t e = 0) {
        if (!std::isfinite(m) || m < 0) throw std::domain_error("InvalidAmount");
        if (m == 0) return {};
        int shift = int(std::floor(std::log10(m)));
        // Avoid pow(10,-324) becoming zero for the smallest subnormal input.
        long double c = static_cast<long double>(m) / std::pow(10.L, shift);
        if (e > limit - shift && shift > 0) throw std::overflow_error("AmountRangeExceeded");
        if (e < -limit - shift && shift < 0) return {};
        e += shift;
        m = significant(double(c), 15);
        if (m >= 10) { m /= 10; ++e; }
        if (m < 1) { m *= 10; --e; }
        if (e > limit) throw std::overflow_error("AmountRangeExceeded");
        if (e < -limit) return {};
        Amount a; a.coefficient_ = m; a.power_ = e; return a;
    }
    static Amount decimal(const std::string &text) {
        static const std::regex syntax(R"(^\+?([0-9]+)(?:\.([0-9]*))?(?:[eE]([+-]?[0-9]+))?$)");
        std::smatch found;
        if (!std::regex_match(text, found, syntax)) throw std::domain_error("InvalidAmountDecimal");
        std::string digits = found[1].str() + found[2].str();
        auto first = digits.find_first_not_of('0');
        if (first == std::string::npos) return {};
        int64_t exponent = 0;
        try { if (found[3].matched) exponent = std::stoll(found[3].str()); }
        catch (...) {
            if (found[3].str().front() == '-') return {};
            throw std::overflow_error("AmountRangeExceeded");
        }
        int64_t shift = int64_t(found[1].length()) - int64_t(first) - 1;
        if (exponent > limit - shift) throw std::overflow_error("AmountRangeExceeded");
        if (exponent < -limit - shift) return {};
        exponent += shift;
        std::string tail = digits.substr(first);
        bool round_up = tail.size() > 15 && tail[15] >= '5';
        tail.resize(15, '0');
        uint64_t significand = std::stoull(tail) + uint64_t(round_up);
        if (significand == 1000000000000000ULL) {
            significand /= 10;
            if (++exponent > limit) throw std::overflow_error("AmountRangeExceeded");
        }
        return normalized(double(significand) / 1e14, exponent);
    }
    double mantissa() const { return coefficient_; }
    int64_t exponent() const { return power_; }
    std::string mantissa_text() const {
        std::ostringstream out; out << std::setprecision(15) << coefficient_; return out.str();
    }
    int compare(const Amount &b) const {
        if (coefficient_ == 0 || b.coefficient_ == 0)
            return coefficient_ == b.coefficient_ ? 0 : coefficient_ == 0 ? -1 : 1;
        if (power_ != b.power_) return power_ < b.power_ ? -1 : 1;
        return coefficient_ == b.coefficient_ ? 0 : coefficient_ < b.coefficient_ ? -1 : 1;
    }
    Amount add(const Amount &b) const {
        if (!coefficient_) return b;
        if (!b.coefficient_) return *this;
        if (power_ < b.power_) return b.add(*this);
        int64_t difference = power_ - b.power_;
        return difference > 16 ? *this : normalized(coefficient_ + b.coefficient_ * std::pow(10., -double(difference)), power_);
    }
    Amount subtract(const Amount &b) const {
        if (compare(b) <= 0) return {};
        if (!b.coefficient_ || power_ - b.power_ > 16) return *this;
        if (power_ - b.power_ <= 1) {
            // Canonical mantissas have 15 decimal digits. Resolve close
            // cancellation in that representation before returning to double.
            int64_t left = decimal_significand();
            int64_t right = b.decimal_significand();
            if (power_ != b.power_) left *= 10;
            return normalized(double(left - right), b.power_ - 14);
        }
        return normalized(std::max(0., coefficient_ - b.coefficient_ * std::pow(10., double(b.power_ - power_))), power_);
    }
    Amount multiply(const Amount &b) const {
        return normalized(coefficient_ * b.coefficient_, power_ + b.power_);
    }
    Amount divide(const Amount &b) const {
        if (!b.coefficient_) throw std::domain_error("AmountDivisionByZero");
        return normalized(coefficient_ / b.coefficient_, power_ - b.power_);
    }
    long double logarithm() const {
        if (!coefficient_) throw std::domain_error("AmountLogZero");
        return std::log10(static_cast<long double>(coefficient_)) + power_;
    }
    static Amount from_log(long double value) {
        if (!std::isfinite(value) || value >= static_cast<long double>(limit) + 1)
            throw std::overflow_error("AmountRangeExceeded");
        if (value < -static_cast<long double>(limit)) return {};
        long double integral = std::floor(value);
        return normalized(double(std::pow(10.L, value - integral)), int64_t(integral));
    }
    Amount power(double n) const {
        if (!std::isfinite(n)) throw std::domain_error("InvalidAmountPower");
        if (!coefficient_) {
            if (n < 0) throw std::domain_error("AmountDivisionByZero");
            return n == 0 ? normalized(1) : Amount();
        }
        return from_log(logarithm() * n);
    }
    Amount floor_value() const {
        if (!coefficient_ || power_ >= 15) return *this;
        if (power_ < 0) return {};
        return normalized(double(decimal_significand() / integer_unit()));
    }
    Amount ceil_value() const {
        if (!coefficient_ || power_ >= 15) return *this;
        if (power_ < 0) return normalized(1);
        int64_t unit = integer_unit();
        return normalized(double((decimal_significand() + unit - 1) / unit));
    }
    Amount rounded(int digits) const {
        if (digits < 1 || digits > 15) throw std::domain_error("AmountPrecision");
        return normalized(significant(coefficient_, digits), power_);
    }
    double ratio(const Amount &b) const {
        if (!b.coefficient_) throw std::domain_error("AmountDivisionByZero");
        if (compare(b) >= 0) return 1;
        if (!coefficient_ || power_ - b.power_ < -324) return 0;
        return std::clamp(coefficient_ / b.coefficient_ * std::pow(10., double(power_ - b.power_)), 0., 1.);
    }
    // S(r,n), with log1p/expm1 keeping r~1 stable. No enormous double sum.
    static Amount geometric(double r, int64_t n) {
        if (!std::isfinite(r) || r <= 0 || n < 0) throw std::domain_error("InvalidGeometricSum");
        if (!n) return {};
        if (r == 1) return decimal(std::to_string(n));
        long double q = std::log1p(static_cast<long double>(r) - 1), x = q * n;
        long double log_sum = x > 500 ? x / std::log(10.L) - std::log10(std::expm1(q))
            : std::log10(std::expm1(x) / std::expm1(q));
        return from_log(log_sum);
    }
};
}
