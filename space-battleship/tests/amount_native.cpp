#include "../addons/native_battle/src/amount.h"
#include "../addons/native_battle/src/module_evaluation.h"
#include <cassert>
#include <iostream>

using space::Amount;
int main() {
    auto a=Amount::from_decimal("1e500"), b=Amount::from_decimal("1e499");
    assert(a.add(b).compare(Amount::from_decimal("1.1e500"))==0);
    assert(a.mul(b).compare(Amount::from_decimal("1e999"))==0);
    assert(a.div(b).compare(Amount(10))==0);
    assert(a.pow(2).compare(Amount::from_decimal("1e1000"))==0);
    assert(a.sub_nonnegative(a).m==0);
    assert(a.sub_nonnegative(a.mul(Amount(2))).m==0);
    assert(Amount(0).e==0);
    assert(Amount::from_decimal("0.00001").e==-5);
    assert(Amount::from_decimal("1e-9000000000000001").m==0);
    assert(Amount::from_decimal("1e-9000000000100001").m==0);
    assert(Amount::from_decimal("1e-999999999999999999999999").m==0);
    assert(Amount::from_decimal("0e999999999999999999999999").m==0);
    assert(Amount::decode("1","500").compare(a)==0);
    assert(Amount(0.1,Amount::limit+1).e==Amount::limit);
    assert(Amount(100,-Amount::limit-1).e==-Amount::limit+1);
    assert(Amount(1,Amount::limit).div(Amount(9,-1)).e==Amount::limit);
    bool rejected=false;try { Amount::decode("0","1"); } catch(...) {rejected=true;}assert(rejected);
    rejected=false;try { a.div(Amount()); } catch(...) {rejected=true;}assert(rejected);
    rejected=false;try { Amount::from_decimal("NaN"); } catch(...) {rejected=true;}assert(rejected);
    rejected=false;try { Amount::from_decimal("-1"); } catch(...) {rejected=true;}assert(rejected);
    rejected=false;try { Amount::from_decimal("1e9000000000000000").mul(Amount(10)); } catch(...) {rejected=true;}assert(rejected);
    assert(Amount::sum_geometric(Amount(2),2,4).compare(Amount(30))==0);
    assert(std::abs(Amount::sum_geometric(Amount(1),1.000000000001,10000).div(Amount(10000)).log10())<1e-8);
    assert(Amount::sum_geometric(Amount(1),2,100000).e>30000);
    assert(Amount(1).to_ratio(a)==0);
    assert(Amount(2).to_ratio(Amount(4))==0.5);
    assert(Amount(6.01).ceil().compare(Amount(7))==0);
    assert(Amount(6.99).floor().compare(Amount(6))==0);
    for(int i=0;i<=10000;++i) {
        auto integer=Amount::from_decimal(std::to_string(i));
        assert(integer.floor().compare(integer)==0);
        assert(integer.ceil().compare(integer)==0);
    }
    assert(Amount::from_decimal("201.000000001").ceil().compare(Amount(202))==0);
    assert(Amount::from_decimal("200.999999999").floor().compare(Amount(200))==0);
    assert(Amount::from_decimal("999999999999999").floor().compare(Amount::from_decimal("999999999999999"))==0);
    assert(Amount(1.23456).round_significant(3).compare(Amount(1.23))==0);
    space::ModuleInput module;
    module.charged_base=Amount(10);module.history_count=100;module.effective_level=2;module.growth=0.1;
    module.branch_factors={Amount(1.5)};module.external_factors={Amount(2)};
    auto evaluated=space::evaluate_module(module);
    assert(evaluated.history_enhanced.compare(Amount(14))==0);
    assert(evaluated.final.compare(Amount(42))==0);
    module.charged_base=Amount::from_decimal("1e500");module.history_count=9007199254740993LL;module.effective_level=1;module.growth=1;
    module.branch_factors.clear();module.external_factors.clear();
    assert(space::evaluate_module(module).final.compare(Amount::from_decimal("1.7e501"))==0);
    std::cout<<"Amount native boundary checks passed\n";
}
