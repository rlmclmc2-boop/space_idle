#include "../addons/native_battle/src/amount.h"
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
    assert(Amount(1.23456).round_significant(3).compare(Amount(1.23))==0);
    std::cout<<"Amount native boundary checks passed\n";
}
