// Written in the D programming language
// License: http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0

import std.array, std.algorithm, std.conv;
import std.functional, std.range;
import expression, declaration, util;

bool isSameType(Expression lhs,Expression rhs){
	return lhs.eval() == rhs.eval(); // TODO: evaluation context?
}

enum NumericType{
	none,
	Bool,
	ℕt,
	ℤt,
	ℚt,
	ℝ,
	ℂ,
}

NumericType whichNumeric(Expression t){ // TODO: more general solution
	import std.traits: EnumMembers;
	static foreach(type;[EnumMembers!NumericType].filter!(x=>x!=NumericType.none))
		if(mixin(text("cast(",to!string(type).endsWith("t")?to!string(type)[0..$-1]:to!string(type),"Ty)t"))) return type;
	return NumericType.none;
}

bool isNumeric(Expression t){
	return whichNumeric(t)!=NumericType.none;
}

Expression getNumeric(int which,bool classical){
	final switch(which){
		import std.traits: EnumMembers;
		static foreach(type;[EnumMembers!NumericType].filter!(x=>x!=NumericType.none))
			case mixin(text("NumericType.",type)): return mixin(text(type))(classical);
		case NumericType.none: return null;
	}
}

string preludeNumericTypeName(Expression e){
	import parser: preludePath;
	import semantic_: modules;
	if(preludePath() !in modules) return null;
	auto exprssc=modules[preludePath()];
	auto sc=exprssc[1];
	auto ce=cast(CallExp)e;
	if(!ce) return null;
	auto id=cast(Identifier)ce.e;
	if(!id) return null;
	if(!id.meaning||id.meaning.scope_ !is sc) return null;
	return id.name;
}

bool isInt(Expression e){ return preludeNumericTypeName(e)=="int"; }
bool isUint(Expression e){ return preludeNumericTypeName(e)=="uint"; }
bool isFloat(Expression e){ return preludeNumericTypeName(e)=="float"; }
bool isRat(Expression e){ return preludeNumericTypeName(e)=="rat"; }

bool isSubtype(Expression lhs,Expression rhs){
	if(!lhs||!rhs) return false;
	auto l=lhs.eval(), r=rhs.eval();
	auto wl=whichNumeric(l), wr=whichNumeric(r);
	if(!lhs.isClassical()&&rhs.isClassical()) return false;
	if(wl==NumericType.none||wr==NumericType.none) return l.isSubtypeImpl(r);
	return wl<=wr;
}

Expression combineTypes(Expression lhs,Expression rhs,bool meet){ // TODO: more general solution // TODO: ⊤/⊥?
	if(!lhs) return rhs;
	if(!rhs) return lhs;
	if(lhs == rhs) return lhs;
	auto l=lhs.eval(), r=rhs.eval();
	auto wl=whichNumeric(l), wr=whichNumeric(r);
	if(wl==NumericType.none&&wr==NumericType.none) return l.combineTypesImpl(r,meet);
	if(wl==NumericType.none||wr==NumericType.none) return null;
	return getNumeric(meet?min(wl,wr):max(wl,wr),meet?lhs.isClassical()||rhs.isClassical():lhs.isClassical()&&rhs.isClassical());
}

Expression joinTypes(Expression lhs,Expression rhs){
	return combineTypes(lhs,rhs,false);
}
Expression meetTypes(Expression lhs,Expression rhs){
	return combineTypes(lhs,rhs,true);
}

class Type: Expression{
	this(){ if(!this.type) this.type=typeTy; sstate=SemState.completed; }
	override @property string kind(){ return "type"; }
	override string toString(){ return "T"; }
	abstract override bool opEquals(Object r);
	abstract override bool isClassical();
	override Annotation getAnnotation(){ return Annotation.lifted; }
}

class ErrorTy: Type{
	this(){}//{sstate = SemState.error;}
	override string toString(){return "__error";}
	override bool isClassical(){ return true; }
	mixin VariableFree;
}

class BoolTy: Type{
	private bool classical;
	private this(bool classical){ this.classical=classical; }
	override string toString(){
		return classical?"!𝔹":"𝔹";
	}
	override bool opEquals(Object o){
		auto r=cast(BoolTy)o;
		return r && classical==r.classical;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return classical;
	}
	override BoolTy getClassical(){
		return Bool(true);
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}
private BoolTy[2] theBool;

BoolTy Bool(bool classical){ return theBool[classical]?theBool[classical]:(theBool[classical]=new BoolTy(classical)); }

class ℕTy: Type{
	private bool classical;
	private this(bool classical){ this.classical=classical; }
	override string toString(){
		return classical?"!ℕ":"ℕ";
	}
	override bool opEquals(Object o){
		auto r=cast(ℕTy)o;
		return r&&classical==r.classical;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return classical;
	}
	override ℕTy getClassical(){
		return ℕt(true);
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}
private ℕTy[2] theℕ;

ℕTy ℕt(bool classical){ return theℕ[classical]?theℕ[classical]:(theℕ[classical]=new ℕTy(classical)); }

class ℤTy: Type{
	private bool classical;
	private this(bool classical){ this.classical=classical; }
	override string toString(){
		return classical?"!ℤ":"ℤ";
	}
	override bool opEquals(Object o){
		auto r=cast(ℤTy)o;
		return r&&classical==r.classical;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return classical;
	}
	override ℤTy getClassical(){
		return ℤt(true);
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}
private ℤTy[2] theℤ;

ℤTy ℤt(bool classical){ return theℤ[classical]?theℤ[classical]:(theℤ[classical]=new ℤTy(classical)); }

class ℚTy: Type{
	private bool classical;
	private this(bool classical){ this.classical=classical; }
	override string toString(){
		return classical?"!ℚ":"ℚ";
	}
	override bool opEquals(Object o){
		auto r=cast(ℚTy)o;
		return r&&classical==r.classical;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return classical;
	}
	override ℚTy getClassical(){
		return ℚt(true);
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}
private ℚTy[2] theℚ;

ℚTy ℚt(bool classical){ return theℚ[classical]?theℚ[classical]:(theℚ[classical]=new ℚTy(classical)); }

class ℝTy: Type{
	private bool classical;
	private this(bool classical){ this.classical=classical; }
	override string toString(){
		return classical?"!ℝ":"ℝ";
	}
	override bool opEquals(Object o){
		auto r=cast(ℝTy)o;
		return r&&classical==r.classical;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return classical;
	}
	override ℝTy getClassical(){
		return ℝ(true);
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}
private ℝTy[2] theℝ;

ℝTy ℝ(bool classical){ return theℝ[classical]?theℝ[classical]:(theℝ[classical]=new ℝTy(classical)); }

class ℂTy: Type{
	private bool classical;
	private this(bool classical){ this.classical=classical; }
	override string toString(){
		return classical?"!ℂ":"ℂ";
	}
	override bool opEquals(Object o){
		auto r=cast(ℂTy)o;
		return r&&classical==r.classical;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return classical;
	}
	override ℂTy getClassical(){
		return ℂ(true);
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}
private ℂTy[2] theℂ;

ℂTy ℂ(bool classical){ return theℂ[classical]?theℂ[classical]:(theℂ[classical]=new ℂTy(classical)); }



class AggregateTy: Type{
	DatDecl decl;
	bool classical;
	private AggregateTy classicalTy;
	this(DatDecl decl,bool classical){
		if(!classical) assert(decl.isQuantum);
		this.decl=decl;
		this.classical=classical;
		if(classical) classicalTy=this;
		else classicalTy=New!AggregateTy(decl,true);
	}
	override bool opEquals(Object o){
		if(auto r=cast(AggregateTy)o)
			return decl is r.decl && classical==r.classical;
		return false;
	}
	override string toString(){
		return decl.name.name;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return classical;
	}
	override AggregateTy getClassical(){
		return classicalTy;
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) e){
		return 0;
	}
}

class ContextTy: Type{
	private this(bool classical){
		this.classical=classical;
	}
	override bool opEquals(Object o){
		auto ctx=cast(ContextTy)o;
		return ctx&&ctx.classical==classical;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return classical;
	}
	override string toString(){
		return (classical?"!":"")~"`Ctx";
	}
	private bool classical;
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) e){
		return 0;
	}
}
private ContextTy[2] theContextTy;
ContextTy contextTy(bool classical){ return theContextTy[classical]?theContextTy[classical]:(theContextTy[classical]=new ContextTy(classical)); }



class TupleTy: Type{
	Expression[] types;
	private this(Expression[] types)in{
		assert(types.all!(x=>x.type==typeTy));
	}body{
		this.types=types;
	}
	override string toString(){
		if(!types.length) return "𝟙";
		if(types.length==1) return "("~types[0].toString()~")¹";
		string addp(Expression a){
			if(cast(FunTy)a) return "("~a.toString()~")";
			return a.toString();
		}
		return types.map!(a=>cast(TupleTy)a&&a!is unit?"("~a.toString()~")":addp(a)).join(" × ");
	}
	override int freeVarsImpl(scope int delegate(string) dg){
		foreach(t;types)
			if(auto r=t.freeVarsImpl(dg))
				return r;
		return 0;
	}
	override TupleTy substituteImpl(Expression[string] subst){
		auto ntypes=types.dup;
		foreach(ref t;ntypes) t=t.substitute(subst);
		return tupleTy(ntypes);
	}
	override bool unifyImpl(Expression rhs,ref Expression[string] subst,bool meet){
		auto tt=cast(TupleTy)rhs;
		if(!tt||types.length!=tt.types.length) return false;
		return all!(i=>types[i].unify(tt.types[i],subst,meet))(iota(types.length));

	}
	override bool opEquals(Object o){
		if(auto r=cast(TupleTy)o)
			return types==r.types;
		return false;
	}
	override bool isSubtypeImpl(Expression r){
		auto ltup=this,rtup=cast(TupleTy)r;
		if(!rtup||ltup.types.length!=rtup.types.length) return false;
		return all!(i=>isSubtype(ltup.types[i],rtup.types[i]))(iota(ltup.types.length));
	}
	override Expression combineTypesImpl(Expression r,bool meet){
		auto ltup=this,rtup=cast(TupleTy)r;
		if(!rtup||ltup.types.length!=rtup.types.length) return null;
		auto rtypes=zip(ltup.types,rtup.types).map!((t)=>combineTypes(t.expand,meet)).array;
		if(any!(x=>x is null)(rtypes)) return null;
		return tupleTy(rtypes);
	}
	override bool isClassical(){
		return all!(x=>x.isClassical())(types);
	}
	override bool hasClassicalComponent(){
		return any!(x=>x.isClassical())(types);
	}
	override Expression getClassical(){
		auto ntypes=types.map!(x=>x.getClassical()).array;
		if(ntypes.any!(x=>x is null)) return null;
		return tupleTy(ntypes);
	}
	override int componentsImpl(scope int delegate(Expression) dg){
		foreach(x;types) if(auto r=dg(x)) return r;
		return 0;
	}
}

TupleTy unit(){ return tupleTy([]); }

TupleTy tupleTy(Expression[] types)in{
	assert(types.all!(x=>x.type==typeTy));
}body{
	return memoize!((Expression[] types)=>new TupleTy(types))(types);
}

size_t numComponents(Expression t){
	if(auto tpl=cast(TupleTy)t)
		return tpl.types.length;
	return 1;
}

class ArrayTy: Type{
	Expression next;
	private this(Expression next)in{
		assert(next.type==typeTy);
	}body{
		this.next=next;
	}
	override string toString(){
		bool p=cast(FunTy)next||cast(TupleTy)next&&next!is unit;
		return p?"("~next.toString()~")[]":next.toString()~"[]";
	}
	override int freeVarsImpl(scope int delegate(string) dg){
		return next.freeVarsImpl(dg);
	}
	override ArrayTy substituteImpl(Expression[string] subst){
		return arrayTy(next.substitute(subst));
	}
	override bool unifyImpl(Expression rhs,ref Expression[string] subst,bool meet){
		auto at=cast(ArrayTy)rhs;
		return at && next.unifyImpl(at.next,subst,meet);
	}
	override ArrayTy eval(){
		return arrayTy(next.eval());
	}
	override bool opEquals(Object o){
		if(auto r=cast(ArrayTy)o)
			return next==r.next;
		return false;
	}
	override bool isSubtypeImpl(Expression r){
		auto larr=this,rarr=cast(ArrayTy)r;
		if(!rarr) return false;
		return isSubtype(larr.next,rarr.next);
	}
	override Expression combineTypesImpl(Expression r,bool meet){
		auto larr=this,rarr=cast(ArrayTy)r;
		if(!rarr) return null;
		return arrayTy(combineTypes(larr.next,rarr.next,meet));
	}
	override bool isClassical(){
		return next.isClassical();
	}
	override bool hasClassicalComponent(){
		return true; // length is classical
	}
	override Expression getClassical(){
		auto nnext=next.getClassical();
		if(!nnext) return null;
		return arrayTy(nnext);
	}
	override int componentsImpl(scope int delegate(Expression) dg){
		return dg(next);
	}
}

ArrayTy arrayTy(Expression next)in{
	assert(next&&next.type==typeTy);
}body{
	return memoize!((Expression next)=>new ArrayTy(next))(next);
}

class VectorTy: Type{
	Expression next,num;
	private this(Expression next,Expression num)in{
		assert(next.type==typeTy);
	}body{
		this.next=next;
		this.num=num;
	}
	override string toString(){
		bool p=cast(FunTy)next||cast(TupleTy)next&&next!is unit;
		bool q=!cast(Identifier)num&&!cast(LiteralExp)num; // TODO: improve
		return (p?"("~next.toString()~")^":next.toString()~"^")~(q?"("~num.toString()~")":num.toString());
	}
	override int freeVarsImpl(scope int delegate(string) dg){
		if(auto r=next.freeVarsImpl(dg)) return r;
		return num.freeVarsImpl(dg);
	}
	override VectorTy substituteImpl(Expression[string] subst){
		return vectorTy(next.substitute(subst),num.substitute(subst));
	}
	override bool unifyImpl(Expression rhs,ref Expression[string] subst,bool meet){
		auto vt=cast(VectorTy)rhs;
		return vt && next.unifyImpl(vt.next,subst,meet) && num.unifyImpl(vt.num,subst,meet);
	}
	override VectorTy eval(){
		return vectorTy(next.eval(),num.eval());
	}
	override bool opEquals(Object o){
		if(auto r=cast(VectorTy)o)
			return next==r.next&&num==r.num;
		return false;
	}
	override bool isSubtypeImpl(Expression r){
		if(auto rarr=cast(ArrayTy)r) return isSubtype(next,rarr.next);
		auto lvec=this,rvec=cast(VectorTy)r;
		if(!rvec) return false;
		return isSubtype(lvec.next,rvec.next) && num==rvec.num;
	}
	override Expression combineTypesImpl(Expression r,bool meet){
		auto larr=this,rarr=cast(VectorTy)r;
		if(!rarr||num!=rarr.num) return null;
		return vectorTy(combineTypes(larr.next,rarr.next,meet),num);
	}
	override bool isClassical(){
		return next.isClassical();
	}
	override bool hasClassicalComponent(){
		return next.hasClassicalComponent();
	}
	override Expression getClassical(){
		auto nnext=next.getClassical();
		if(!nnext) return null;
		return vectorTy(nnext,num);
	}
	override int componentsImpl(scope int delegate(Expression) dg){
		if(auto r=dg(next)) return r;
		return dg(num);
	}
}

VectorTy vectorTy(Expression next,Expression num)in{
	assert(next&&next.type==typeTy);
	assert(num&&isSubtype(num.type,ℕt(true)));
}body{
	return memoize!((Expression next,Expression num)=>new VectorTy(next,num))(next,num);
}

static Expression elementType(Expression ty){
	if(auto at=cast(ArrayTy)ty) return at.next;
	if(auto vt=cast(VectorTy)ty) return vt.next;
	return null;
}



class StringTy: Type{
	bool classical;
	private this(bool classical){ this.classical=classical; }
	override string toString(){
		return classical?"!string":"string";
	}
	override bool opEquals(Object o){
		return !!cast(StringTy)o;
	}
	override bool isClassical(){
		return classical;
	}
	override bool hasClassicalComponent(){
		return true; // length is classical
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}

StringTy stringTy(bool classical){ return memoize!((bool classical)=>new StringTy(classical))(classical); }

enum Annotation{
	none,
	mfree,
	lifted,
}

class RawProductTy: Expression{
	Parameter[] params;
	Expression cod;
	bool isSquare,isTuple;
	Annotation annotation;
	this(Parameter[] params,Expression cod,bool isSquare,bool isTuple,Annotation annotation){
		this.params=params; this.cod=cod;
		this.isSquare=isSquare; this.isTuple=isTuple;
		this.annotation=annotation;
	}
	override string toString(){
		return "<unanalyzed Π type>"; // TODO: format nicely.
	}
	override bool isClassical(){
		assert(0);
	}
	override bool hasClassicalComponent(){
		assert(0);
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}

class ProductTy: Type{
	bool[] isConst;
	string[] names;
	Expression dom, cod;
	bool isSquare,isTuple;
	Annotation annotation;
	bool isClassical_;
	private ProductTy classicalTy;
	private this(bool[] isConst,string[] names,Expression dom,Expression cod,bool isSquare,bool isTuple,Annotation annotation,bool isClassical_)in{
		// TODO: assert that all names are distinct
		if(isTuple){
			auto tdom=cast(TupleTy)dom;
			assert(!!tdom);
			assert(names.length==tdom.types.length);
		}else assert(names.length==1);
		assert(cod.type==typeTy,text(cod));
	}body{
		this.isConst=isConst;
		this.names=names; this.dom=dom; this.cod=cod;
		this.isSquare=isSquare; this.isTuple=isTuple;
		this.annotation=annotation;
		this.isClassical_=isClassical_;
		if(this.isClassical) classicalTy=this;
		else classicalTy=new ProductTy(isConst,names,dom,cod,isSquare,isTuple,annotation,true);
		// TODO: report DMD bug, New!ProductTy does not work
	}
	/+private+/ @property TupleTy tdom()in{ // TODO: make private
		assert(isTuple);
	}body{
		auto r=cast(TupleTy)dom;
		assert(!!r);
		return r;
	}
	override string toString(){
		auto c=cod.toString();
		auto del=isSquare?"[]":"()";
		string r;
		if(!cod.hasAnyFreeVar(names)){
			string d;
			string addp(bool const_,Expression a){
				if(const_&&a.impliesConst()) const_=false;
				if(cast(FunTy)a) return "("~(const_?"const (":"")~a.toString()~(const_?")":"")~")";
				if(cast(TupleTy)a) return (const_?"const (":"")~a.toString()~(const_?")":"");
				return (const_?"const ":"")~a.toString();
			}
			if(all!(x=>!x)(isConst)){
				d=dom.toString();
			}else if(auto tpl=cast(TupleTy)dom){
				if(isTuple){
					assert(!!tpl.types.length);
					if(tpl.types.length==1) return "("~(isConst[0]?"const ":"")~tpl.types[0].toString()~")¹";
					assert(tpl.types.length==isConst.length);
					d=zip(isConst,tpl.types).map!(a=>(cast(TupleTy)a[1]&&a[1]!is unit?"("~(a[0]?"const ":"")~a[1].toString()~")":addp(a[0],a[1]))).join(" × ");
				}else d=addp(isConst[0],dom);
			}else d=addp(isConst[0],dom);
			if(isSquare||!isTuple&&nargs==1&&cast(FunTy)argTy(0)) d=del[0]~d~del[1];
			r=d~" →"~(annotation?to!string(annotation):"")~" "~c;
		}else{
			assert(names.length);
			string args;
			if(isTuple){
				args=zip(isConst,names,tdom.types).map!(x=>(x[0]?"const ":"")~x[1]~":"~x[2].toString()).join(",");
				if(nargs==1) args~=",";
			}else args=(isConst[0]?"const ":"")~names[0]~":"~dom.toString();
			r="∏"~del[0]~args~del[1]~(annotation?to!string(annotation):"")~". "~c;
		}
		if(isClassical_) r="!("~r~")";
		return r;
	}
	@property size_t nargs(){
		if(isTuple) return tdom.types.length;
		return 1;
	}
	Expression argTy(size_t i)in{assert(i<nargs);}body{
		if(isTuple) return tdom.types[i];
		return dom;
	}
	override int freeVarsImpl(scope int delegate(string) dg){
		if(auto r=dom.freeVarsImpl(dg)) return r;
		return cod.freeVarsImpl(v=>names.canFind(v)?0:dg(v));
	}
	private ProductTy relabel(string oname,string nname)in{
		assert(names.canFind(oname));
		assert(!hasFreeVar(nname));
		assert(!names.canFind(nname));
	}out(r){
		assert(r.names.canFind(nname));
		assert(!r.names.canFind(oname));
	}body{
		if(oname==nname) return this;
		import std.algorithm;
		auto i=names.countUntil(oname);
		assert(i!=-1);
		auto nnames=names.dup;
		nnames[i]=nname;
		auto nvar=varTy(nname,argTy(i));
		return productTy(isConst,nnames,dom,cod.substitute(oname,nvar),isSquare,isTuple,annotation,isClassical_);
	}
	private ProductTy relabelAway(string oname)in{
		assert(names.canFind(oname));
	}out(r){
		assert(!r.names.canFind(oname));
	}body{
		auto nname=oname;
		while(names.canFind(nname)||hasFreeVar(nname)) nname~="'";
		return relabel(oname,nname);
	}
	private string freshName(string base,Expression block){
		auto nn=base;
		while(hasFreeVar(nn)||block.hasFreeVar(nn)) nn~="'";
		return nn;
	}
	private string[] freshNames(Expression block){
		auto nnames=names.dup;
		foreach(i,ref nn;nnames)
			while(hasFreeVar(nn)||block.hasFreeVar(nn)||nnames[0..i].canFind(nn)) nn~="'";
		return nnames;
	}
	private ProductTy relabelAll(string[] nnames)out(r){
		assert(nnames.length==names.length);
		foreach(n;nnames) assert(!hasFreeVar(n));
	}body{
		Expression[string] subst;
		foreach(i;0..names.length) subst[names[i]]=varTy(nnames[i],argTy(i));
		return productTy(isConst,nnames,dom,cod.substitute(subst),isSquare,isTuple,annotation,isClassical_);
	}
	override ProductTy substituteImpl(Expression[string] subst){
		foreach(n;names){
			bool ok=true;
			foreach(k,v;subst) if(v.hasFreeVar(n)) ok=false;
			if(ok) continue;
			auto r=cast(ProductTy)relabelAway(n).substitute(subst);
			assert(!!r);
			return r;
		}
		auto ndom=dom.substitute(subst);
		auto nsubst=subst.dup;
		foreach(n;names) nsubst.remove(n);
		auto ncod=cod.substitute(nsubst);
		auto nIsConst=isConst;
		if(auto tpl=cast(TupleTy)ncod){ // TODO: it might be better to maintain this invariant upon construction
			assert(nIsConst.length==tpl.types.length);
			if(iota(nIsConst.length).any!(i=>!nIsConst[i]&&tpl.types[i].impliesConst)){
				nIsConst=nIsConst.dup;
				foreach(i;0..nIsConst.length) if(!nIsConst[i]&&tpl.types[i].impliesConst) nIsConst[i]=true;
			}
		}else if(ncod.impliesConst&&iota(nIsConst.length).any!(i=>!nIsConst[i]))
			nIsConst=true.repeat(isConst.length).array;
		return productTy(nIsConst,names,ndom,ncod,isSquare,isTuple,annotation,isClassical_);
	}
	override bool unifyImpl(Expression rhs,ref Expression[string] subst,bool meet){
		auto r=cast(ProductTy)rhs; // TODO: get rid of duplication (same code in opEquals)
		if(!r) return false;
		if(isTuple&&!cast(TupleTy)r.dom) return false;
		r=r.setTuple(isTuple);
		if(!r) return false;
		if(isConst!=r.isConst||isSquare!=r.isSquare||annotation!=r.annotation||
		   isClassical_!=r.isClassical_||nargs!=r.nargs)
			return false;
		r=r.relabelAll(freshNames(r));
		Expression[string] nsubst;
		foreach(k,v;subst) if(!names.canFind(k)) nsubst[k]=v;
		auto res=dom.unify(r.dom,nsubst,!meet)&&cod.unify(r.cod,nsubst,meet);
		foreach(k,v;nsubst) subst[k]=v;
		return res;
	}
	Expression tryMatch(Expression arg,out Expression garg)in{assert(isSquare&&cast(ProductTy)cod);}body{
		auto cod=cast(ProductTy)this.cod;
		assert(!!cod);
		auto nnames=freshNames(arg);
		if(nnames!=names) return relabelAll(nnames).tryMatch(arg,garg);
		Expression[] atys;
		auto tpl=cast(TupleTy)arg.type;
		if(cod.isTuple&&tpl){
			atys=tpl.types;
			if(atys.length!=cod.nargs) return null;
		}else atys=[arg.type];
		Expression[string] subst;
		foreach(i,n;names) subst[n]=null;
		foreach(i,aty;atys){
			if(i>=cod.nargs) continue;
			if(!cod.argTy(i).unify(aty,subst,false))
				return null;
		}
		auto gargs=new Expression[](names.length);
		foreach(i,n;names){
			if(!subst[n]) return null;
			gargs[i]=subst[n];
		}
		if(!isTuple) assert(gargs.length==1);
		garg=isTuple?new TupleExp(gargs):gargs[0];
		cod=cast(ProductTy)cod.substitute(subst);
		assert(!!cod);
		return cod.tryApply(arg,false);
	}
	Expression tryApply(Expression arg,bool isSquare){
		if(isSquare != this.isSquare) return null;
		if(!isSubtype(arg.type,dom)) return null;
		Expression[string] subst;
		if(isTuple){
			auto tdom=cast(TupleTy)dom;
			assert(!!tdom);
			foreach(i,n;names){
				import lexer;
				auto lit=new LiteralExp(Token(Tok!"0",to!string(i)));
				lit.type=ℤt(true);
				auto exp=new IndexExp(arg,[lit],false).eval();
				exp.type=tdom.types[i];
				subst[n]=exp;
			}
		}else{
			assert(names.length==1);
			subst[names[0]]=arg;
		}
		return cod.substitute(subst);
	}
	override bool opEquals(Object o){
		auto r=cast(ProductTy)o;
		if(!r) return false;
		if(isTuple&&!cast(TupleTy)r.dom) return false;
		r=r.setTuple(isTuple);
		if(!r) return false;
		assert(isTuple==r.isTuple);
		if(isConst!=r.isConst||isSquare!=r.isSquare||annotation!=r.annotation||
		   isClassical_!=r.isClassical_||nargs!=r.nargs)
			return false;
		r=r.relabelAll(freshNames(r));
		return dom==r.dom&&cod==r.cod;
	}
	override bool isSubtypeImpl(Expression rhs){
		auto r=cast(ProductTy)rhs;
		if(!r) return false;
		if(isTuple&&!cast(TupleTy)r.dom) return false;
		r=r.setTuple(isTuple);
		if(!r) return false;
		if(isConst!=r.isConst||isSquare!=r.isSquare||nargs!=r.nargs)
			return false;
		if(annotation<r.annotation||!isClassical&&r.isClassical)
			return false;
		auto name=freshName("x",r);
		auto vars=varTy(name,r.dom);
		auto lCod=tryApply(vars,isSquare);
		auto rCod=r.tryApply(vars,isSquare);
		if(!lCod) return false;
		assert(!!rCod);
		return isSubtype(lCod,rCod);
	}
	private ProductTy setTuple(bool tuple)in{
		assert(!tuple||cast(TupleTy)dom);
	}body{
		if(tuple==isTuple) return this;
		string[] nnames;
		bool[] nIsConst;
		if(tuple){
			auto tpl=cast(TupleTy)dom;
			assert(!!tpl);
			nnames=iota(tpl.types.length).map!(i=>"x"~lowNum(i)).array;
			assert(isConst.length==1);
			nIsConst=isConst[0].repeat(tpl.types.length).array;
		}else{
			auto isConst2=iota(nargs).filter!(i=>!argTy(i).impliesConst()).map!(i=>isConst[i]);
			if(!isConst2.empty&&!isConst2.all!(x=>x==isConst2.front))
				return null;
			nnames=["x"];
			nIsConst=[isConst2.empty?true:isConst2.front];
		}
		foreach(i,ref nn;nnames) while(hasFreeVar(nn)) nn~="'";
		return productTy(nIsConst,nnames,dom,cod,isSquare,tuple,annotation,isClassical_);
	}
	override bool isClassical(){
		return isClassical_;
	}
	override bool hasClassicalComponent(){
		return true; // code is classical
	}
	override ProductTy getClassical(){
		return classicalTy;
	}
	override int componentsImpl(scope int delegate(Expression) e){
		return 0; // TODO: ok?
	}
}

ProductTy productTy(bool[] isConst,string[] names,Expression dom,Expression cod,bool isSquare,bool isTuple,Annotation annotation,bool isClassical)in{
	assert(dom&&cod);
	if(isTuple){
		auto tdom=cast(TupleTy)dom;
		assert(tdom&&names.length==tdom.types.length);
	}
	assert(annotation<Annotation.lifted||all(isConst));
}body{
	return memoize!((bool[] isConst,string[] names,Expression dom,Expression cod,bool isSquare,bool isTuple,Annotation annotation,bool isClassical)=>new ProductTy(isConst,names,dom,cod,isSquare,isTuple,annotation,isClassical))(isConst,names,dom,cod,isSquare,isTuple,annotation,isClassical);
}

alias FunTy=ProductTy;
FunTy funTy(bool[] isConst,Expression dom,Expression cod,bool isSquare,bool isTuple,Annotation annotation,bool isClassical)in{
	assert(dom&&cod);
	assert(annotation<Annotation.lifted||all(isConst));
}body{
	auto nargs=1+[].length;
	if(isTuple) if(auto tpl=cast(TupleTy)dom) nargs=tpl.types.length;
	return productTy(isConst,iota(nargs).map!(_=>"").array,dom,cod,isSquare,isTuple,annotation,isClassical);
}

FunTy funTy(Expression dom,Expression cod,bool isSquare,bool isTuple,Annotation annotation,bool isClassical)in{
	assert(dom&&cod);
	assert(annotation<Annotation.lifted);
}body{
	auto nargs=1+[].length;
	if(isTuple) if(auto tpl=cast(TupleTy)dom) nargs=tpl.types.length;
	return funTy(false.repeat(nargs).array,dom,cod,isSquare,isTuple,annotation,isClassical);
}

FunTy funTy(Expression dom,Expression cod,bool isSquare,bool isTuple,bool isClassical)in{
	assert(dom&&cod);
}body{
	return funTy(dom,cod,isSquare,isTuple,Annotation.lifted,isClassical);
}

Identifier varTy(string name,Expression type,bool classical=false){
	return memoize!((string name,Expression type,bool classical){
		auto r=new Identifier(name);
		r.classical=classical;
		r.type=type;
		r.sstate=SemState.completed;
		return r;
	})(name,type,classical);
}

struct FreeIdentifiers{
	Expression self;
	int opApply(scope int delegate(Identifier) dg){
		int rec(Expression e){
			if(auto id=cast(Identifier)e) if(auto r=dg(id)) return r;
			// TODO: ProductTy, LambdaExp
			foreach(x;e.components)
				if(auto r=rec(x))
					return r;
			return 0;
		}
		return rec(self);
	}
}
auto freeIdentifiers(Expression self){
	return FreeIdentifiers(self);
}
bool hasFreeIdentifier(Expression self,string name){
	foreach(id;self.freeIdentifiers) if(id.name==name) return true;
	return false;
}

class TypeTy: Type{
	this(){ this.type=this; super(); }
	override string toString(){
		return "*";
	}
	override bool opEquals(Object o){
		return !!cast(TypeTy)o;
	}
	override bool isClassical(){
		return true; // quantum superposition of multiple types not allowed
	}
	override bool hasClassicalComponent(){
		return true;
	}
	mixin VariableFree;
	override int componentsImpl(scope int delegate(Expression) dg){
		return 0;
	}
}
private TypeTy theTypeTy;
TypeTy typeTy(){ return theTypeTy?theTypeTy:(theTypeTy=new TypeTy()); }
