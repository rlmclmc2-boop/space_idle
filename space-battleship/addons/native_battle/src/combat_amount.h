#pragma once
#include "amount_binding.h"
#include <type_traits>

// Operator/Variant adapter only. Arithmetic stays in the shared Amount value;
// no implicit conversion back to double is offered to combat code.
struct CombatAmount : space::Amount {
    CombatAmount() = default;
    CombatAmount(double value) : space::Amount(value) {}
    CombatAmount(const space::Amount &value) : space::Amount(value) {}
    CombatAmount(const Variant &value) {
        if (value.get_type()==Variant::DICTIONARY) {
            *static_cast<space::Amount *>(this)=SpaceAmount::read(value);
        } else if (value.get_type()==Variant::INT) {
            *static_cast<space::Amount *>(this)=space::Amount::from_decimal(std::to_string(int64_t(value)));
        } else if (value.get_type()==Variant::FLOAT) {
            *static_cast<space::Amount *>(this)=space::Amount(double(value));
        } else throw std::domain_error("InvalidCombatAmount");
    }
    operator Variant() const { return SpaceAmount::encode(*this); }
    CombatAmount operator+(const CombatAmount &b) const { return add(b); }
    CombatAmount operator-(const CombatAmount &b) const { return sub_nonnegative(b); }
    CombatAmount operator*(const CombatAmount &b) const { return mul(b); }
    CombatAmount operator/(const CombatAmount &b) const { return div(b); }
    CombatAmount &operator+=(const CombatAmount &b) { return *this=add(b); }
    CombatAmount &operator-=(const CombatAmount &b) { return *this=sub_nonnegative(b); }
    CombatAmount &operator*=(const CombatAmount &b) { return *this=mul(b); }
    CombatAmount &operator/=(const CombatAmount &b) { return *this=div(b); }
    bool operator==(const CombatAmount &b) const { return compare(b)==0; }
    bool operator!=(const CombatAmount &b) const { return compare(b)!=0; }
    bool operator<(const CombatAmount &b) const { return compare(b)<0; }
    bool operator<=(const CombatAmount &b) const { return compare(b)<=0; }
    bool operator>(const CombatAmount &b) const { return compare(b)>0; }
    bool operator>=(const CombatAmount &b) const { return compare(b)>=0; }
};

inline CombatAmount operator+(double a,const CombatAmount &b){return CombatAmount(a)+b;}
inline CombatAmount operator-(double a,const CombatAmount &b){return CombatAmount(a)-b;}
inline CombatAmount operator*(double a,const CombatAmount &b){return CombatAmount(a)*b;}
inline CombatAmount operator/(double a,const CombatAmount &b){return CombatAmount(a)/b;}
inline bool operator<(double a,const CombatAmount &b){return CombatAmount(a)<b;}
inline bool operator<=(double a,const CombatAmount &b){return CombatAmount(a)<=b;}
inline bool operator>(double a,const CombatAmount &b){return CombatAmount(a)>b;}
inline bool operator>=(double a,const CombatAmount &b){return CombatAmount(a)>=b;}
inline bool operator==(double a,const CombatAmount &b){return CombatAmount(a)==b;}
inline bool operator!=(double a,const CombatAmount &b){return CombatAmount(a)!=b;}

template<class A,class B> inline auto combat_min(A a,B b) {
    if constexpr(std::is_same_v<A,CombatAmount> || std::is_same_v<B,CombatAmount>) return CombatAmount(space::Amount::min(CombatAmount(a),CombatAmount(b)));
    else {using C=std::common_type_t<A,B>;return std::min(C(a),C(b));}
}
template<class A,class B> inline auto combat_max(A a,B b) {
    if constexpr(std::is_same_v<A,CombatAmount> || std::is_same_v<B,CombatAmount>) return CombatAmount(space::Amount::max(CombatAmount(a),CombatAmount(b)));
    else {using C=std::common_type_t<A,B>;return std::max(C(a),C(b));}
}
inline double combat_ceil(double a){return std::ceil(a);}
inline CombatAmount combat_ceil(const CombatAmount &a){return a.ceil();}
inline bool combat_finite(double a){return std::isfinite(a);}
inline bool combat_finite(const CombatAmount &){return true;}
