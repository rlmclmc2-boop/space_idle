#include "../../addons/native_battle/src/amount_value.hpp"
#include <cassert>
#include <iostream>
#include <functional>
#include <vector>
using foundation::Amount;
int main() {
    auto a = [](const char *s) { return Amount::decimal(s); };
    auto equal = [&](Amount x, const char *expected) { assert(x.compare(a(expected)) == 0); };
    equal(a("1e500").add(a("1e499")), "1.1e500");
    equal(a("2e500").multiply(a("3e499")), "6e999");
    equal(a("6e999").divide(a("2e500")), "3e499");
    equal(a("1e500").power(2), "1e1000");
    equal(a("1.5").power_integer(10), "57.6650390625");
    const Amount guidance_2000 = a("1.5").power_integer(2000);
    assert(guidance_2000 > a("1e308") && guidance_2000 < a("1e400"));
    assert(a("1.5").power_integer(2001) == guidance_2000 * a("1.5"));
    const Amount high_layer_hit = a("1200") * guidance_2000;
    assert(high_layer_hit > a("1e308") && high_layer_hit < a("1e400"));
    equal(a("1").subtract(a("2")), "0");
    equal(a("1e500").subtract(a("9.9999999999999e499")), "1e486");
    equal(a("0.0001").floor_value(), "0");
    equal(a("0.0001").ceil_value(), "1");
    equal(a("123.75").floor_value(), "123");
    equal(a("123.25").ceil_value(), "124");
    equal(a("113").floor_value(), "113");
    equal(a("109").ceil_value(), "109");
    equal(a("112.9999999999").floor_value(), "112");
    equal(a("113.0000000001").ceil_value(), "114");
    equal(a("108.9999999999").floor_value(), "108");
    equal(a("109.0000000001").ceil_value(), "110");
    for (int64_t n = 0; n <= 10000; ++n) {
        auto integer = Amount::decimal(std::to_string(n));
        assert(integer.floor_value().compare(integer) == 0);
        assert(integer.ceil_value().compare(integer) == 0);
    }
    for (const char *n : {"99999999999999", "100000000000113", "999999999999999"}) {
        auto integer = a(n);
        assert(integer.floor_value().compare(integer) == 0);
        assert(integer.ceil_value().compare(integer) == 0);
    }
    equal(a("1e-999999999999999999999999999999"), "0");
    equal(a("9.999999999999994e9000000000000000"), "9.99999999999999e9000000000000000");
    equal(a("201.000000001").ceil_value(), "202");
    equal(a("200.999999999").floor_value(), "200");
    equal(a("1e-9000000000000000").divide(a("10")), "0");
    equal(a("1.25e500").rounded(2), "1.3e500");
    equal(Amount::geometric(1, 10000), "10000");
    equal(Amount::geometric(2, 10), "1023");
    assert(std::abs(double(Amount::geometric(1.00000001, 10000).logarithm()) - std::log10(10000.49996666)) < 1e-8);
    assert(a("1e500").ratio(a("1e499")) == 1);
    assert(a("1e499").ratio(a("1e500")) == 0.1);
    assert(a("1e9000000000000000").compare(a("9e8999999999999999")) > 0);
    for (std::function<void()> f : std::vector<std::function<void()>>{
        std::function<void()>([&] { a("-1"); }), [&] { a("NaN"); },
        [&] { a("1").divide(a("0")); }, [&] { a("1e9000000000000000").power(2); },
        [&] { a("1e9000000000000001"); }, [&] { a("10e9000000000000000"); }, [&] { a("9.999999999999995e9000000000000000"); }, [&] { Amount::normalized(INFINITY); }}) {
        bool rejected = false; try { f(); } catch (const std::exception &) { rejected = true; }
        assert(rejected);
    }
    std::cout << "Amount arithmetic, encoding range and invalid-input boundaries passed\n";
}
