/*
 * Copyright 2022 WebAssembly Community Group participants
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef wasm_ir_possible_contents_h
#define wasm_ir_possible_contents_h

#include <variant>

#include "ir/possible-constant.h"
#include "ir/subtypes.h"
#include "support/small_vector.h"
#include "wasm-builder.h"
#include "wasm.h"

namespace wasm {

//
// PossibleContents represents the possible contents at a particular location
// (such as in a local or in a function parameter). This is a little similar to
// PossibleConstantValues, but considers more types of contents than constant
// values - in particular, it can track types to some extent.
//
// The specific contents this can vary over are:
//
//  * None:            No possible value.
//
//  * Literal:         One possible constant value like an i32 of 42.
//
//  * Global:          The name of a global whose value is here. We do not know
//                     the actual value at compile time, but we know it is equal
//                     to that global. Typically we can only infer this for
//                     immutable globals.
//
//  * ExactType:       Any possible value of a specific exact type - *not*
//                     including subtypes. For example, (struct.new $Foo) has
//                     ExactType contents of type $Foo.
//                     If the type here is nullable then null is also allowed.
//                     TODO: Add ConeType, which would include subtypes.
//                     TODO: Add ExactTypePlusContents or such, which would be
//                           used on e.g. a struct.new with an immutable field
//                           to which we assign a constant: not only do we know
//                           the exact type, but also certain field's values.
//
//  * Many:            Anything else. Many things are possible here, and we do
//                     not track what they might be, so we must assume the worst
//                     in the calling code.
//
class PossibleContents {
  struct None : public std::monostate {};

  struct GlobalInfo {
    Name name;
    // The type of the global in the module. We stash this here so that we do
    // not need to pass around a module all the time.
    // TODO: could we save size in this variant if we did pass around the
    //       module?
    Type type;
    bool operator==(const GlobalInfo& other) const {
      return name == other.name && type == other.type;
    }
  };

  using ExactType = Type;

  struct Many : public std::monostate {};

  // TODO: This is similar to the variant in PossibleConstantValues, and perhaps
  //       we could share code, but extending a variant using template magic may
  //       not be worthwhile. Another option might be to make PCV inherit from
  //       this and disallow ExactType etc., but PCV might get slower.
  using Variant = std::variant<None, Literal, GlobalInfo, ExactType, Many>;
  Variant value;

public:
  PossibleContents() : value(None()) {}
  PossibleContents(const PossibleContents& other) = default;

  template<typename T> explicit PossibleContents(T val) : value(val) {}

  // Most users will use one of the following static functions to construct a
  // new instance:

  static PossibleContents none() { return PossibleContents{None()}; }
  static PossibleContents literal(Literal c) { return PossibleContents{c}; }
  static PossibleContents global(Name name, Type type) {
    return PossibleContents{GlobalInfo{name, type}};
  }
  static PossibleContents exactType(Type type) {
    return PossibleContents{ExactType(type)};
  }
  static PossibleContents many() { return PossibleContents{Many()}; }

  PossibleContents& operator=(const PossibleContents& other) = default;

  bool operator==(const PossibleContents& other) const {
    return value == other.value;
  }

  bool operator!=(const PossibleContents& other) const {
    return !(*this == other);
  }

  // Combine the information in a given PossibleContents to this one. The
  // contents here will then include whatever content was possible in |other|.
  void combine(const PossibleContents& other);

  bool isNone() const { return std::get_if<None>(&value); }
  bool isLiteral() const { return std::get_if<Literal>(&value); }
  bool isGlobal() const { return std::get_if<GlobalInfo>(&value); }
  bool isExactType() const { return std::get_if<Type>(&value); }
  bool isMany() const { return std::get_if<Many>(&value); }

  Literal getLiteral() const {
    assert(isLiteral());
    return std::get<Literal>(value);
  }

  Name getGlobal() const {
    assert(isGlobal());
    return std::get<GlobalInfo>(value).name;
  }

  bool isNull() const { return isLiteral() && getLiteral().isNull(); }

  // Return the relevant type here. Note that the *meaning* of the type varies
  // by the contents: type $foo of a global means that type or any subtype, as a
  // subtype might be written to it, while type $foo of a Literal or an
  // ExactType means that type and nothing else; see hasExactType().
  //
  // If no type is possible, return unreachable; if many types are, return none.
  Type getType() const {
    if (auto* literal = std::get_if<Literal>(&value)) {
      return literal->type;
    } else if (auto* global = std::get_if<GlobalInfo>(&value)) {
      return global->type;
    } else if (auto* type = std::get_if<Type>(&value)) {
      return *type;
    } else if (std::get_if<None>(&value)) {
      return Type::unreachable;
    } else if (std::get_if<Many>(&value)) {
      return Type::none;
    } else {
      WASM_UNREACHABLE("bad value");
    }
  }

  // Returns whether the type we can report here is exact, that is, nothing of a
  // strict subtype might show up - the contents here have an exact type.
  //
  // This is different from isExactType() which checks if all we know about the
  // contents here is their exact type. Specifically, we may know both an exact
  // type and also more than just that, which is the case with a Literal.
  //
  // This returns false for None and Many, for whom it is not well-defined.
  bool hasExactType() const { return isExactType() || isLiteral(); }

  // Whether we can make an Expression* for this containing the proper contents.
  // We can do that for a Literal (emitting a Const or RefFunc etc.) or a
  // Global (emitting a GlobalGet), but not for anything else yet.
  bool canMakeExpression() const { return isLiteral() || isGlobal(); }

  Expression* makeExpression(Module& wasm) {
    assert(canMakeExpression());
    Builder builder(wasm);
    if (isLiteral()) {
      return builder.makeConstantExpression(getLiteral());
    } else {
      auto name = getGlobal();
      return builder.makeGlobalGet(name, wasm.getGlobal(name)->type);
    }
  }

  size_t hash() const {
    // Encode this using three bits for the variant type, then the rest of the
    // contents.
    if (isNone()) {
      return 0;
    } else if (isLiteral()) {
      return size_t(1) | (std::hash<Literal>()(getLiteral()) << 3);
    } else if (isGlobal()) {
      return size_t(2) | (std::hash<Name>()(getGlobal()) << 3);
    } else if (isExactType()) {
      return size_t(3) | (std::hash<Type>()(getType()) << 3);
    } else if (isMany()) {
      return 4;
    } else {
      WASM_UNREACHABLE("bad variant");
    }
  }

  void dump(std::ostream& o, Module* wasm = nullptr) const {
    o << '[';
    if (isNone()) {
      o << "None";
    } else if (isLiteral()) {
      o << "Literal " << getLiteral();
      auto t = getType();
      if (t.isRef()) {
        auto h = t.getHeapType();
        o << " HT: " << h;
      }
    } else if (isGlobal()) {
      o << "GlobalInfo $" << getGlobal();
    } else if (isExactType()) {
      o << "ExactType " << getType();
      auto t = getType();
      if (t.isRef()) {
        auto h = t.getHeapType();
        o << " HT: " << h;
        if (wasm && wasm->typeNames.count(h)) {
          o << " $" << wasm->typeNames[h].name;
        }
        if (t.isNullable()) {
          o << " null";
        }
      }
    } else if (isMany()) {
      o << "Many";
    } else {
      WASM_UNREACHABLE("bad variant");
    }
    o << ']';
  }
};

// The various *Location structs (ExpressionLocation, ResultLocation, etc.)
// describe particular locations where content can appear.

// The location of a specific IR expression.
struct ExpressionLocation {
  Expression* expr;
  // If this expression contains a tuple then each index in the tuple will have
  // its own location with a corresponding tupleIndex. If this is not a tuple
  // then we only use tupleIndex 0.
  Index tupleIndex;
  bool operator==(const ExpressionLocation& other) const {
    return expr == other.expr && tupleIndex == other.tupleIndex;
  }
};

// The location of one of the results of a function.
struct ResultLocation {
  Function* func;
  Index index;
  bool operator==(const ResultLocation& other) const {
    return func == other.func && index == other.index;
  }
};

// The location of one of the locals in a function (either a param or a var).
// TODO: would separating params from vars help? (SSA might be enough)
struct LocalLocation {
  Function* func;
  // The index of the local.
  Index index;
  // As in ExpressionLocation, the index inside the tuple, or 0 if not a tuple.
  Index tupleIndex;
  bool operator==(const LocalLocation& other) const {
    return func == other.func && index == other.index &&
           tupleIndex == other.tupleIndex;
  }
};

// The location of a break target in a function, identified by its name.
struct BreakTargetLocation {
  Function* func;
  Name target;
  // As in ExpressionLocation, the index inside the tuple, or 0 if not a tuple.
  // That is, if the branch target has a tuple type, then each branch to that
  // location sends a tuple, and we'll have a separate BreakTargetLocation for
  // each, indexed by the index in the tuple that the branch sends.
  Index tupleIndex;
  bool operator==(const BreakTargetLocation& other) const {
    return func == other.func && target == other.target &&
           tupleIndex == other.tupleIndex;
  }
};

// The location of a global in the module.
struct GlobalLocation {
  Name name;
  bool operator==(const GlobalLocation& other) const {
    return name == other.name;
  }
};

// The location of one of the parameters in a function signature.
struct SignatureParamLocation {
  HeapType type;
  Index index;
  bool operator==(const SignatureParamLocation& other) const {
    return type == other.type && index == other.index;
  }
};

// The location of one of the results in a function signature.
struct SignatureResultLocation {
  HeapType type;
  Index index;
  bool operator==(const SignatureResultLocation& other) const {
    return type == other.type && index == other.index;
  }
};

// The location of contents in a struct or array (i.e., things that can fit in a
// dataref). Note that this is specific to this type - it does not include data
// about subtypes or supertypes.
struct DataLocation {
  HeapType type;
  // The index of the field in a struct, or 0 for an array (where we do not
  // attempt to differentiate by index).
  Index index;
  bool operator==(const DataLocation& other) const {
    return type == other.type && index == other.index;
  }
};

// The location of anything written to a particular tag.
struct TagLocation {
  Name tag;
  // If the tag has more than one element, we'll have a separate TagLocation for
  // each, with corresponding indexes. If the tag has just one element we'll
  // only have one TagLocation with index 0.
  Index tupleIndex;
  bool operator==(const TagLocation& other) const {
    return tag == other.tag && tupleIndex == other.tupleIndex;
  }
};

// A null value. This is used as the location of the default value of a var in a
// function, a null written to a struct field in struct.new_with_default, etc.
struct NullLocation {
  Type type;
  bool operator==(const NullLocation& other) const {
    return type == other.type;
  }
};

// A special type of location that does not refer to something concrete in the
// wasm, but is used to optimize the graph. A "cone read" is a struct.get or
// array.get of a type that is not exact, so it can read the "cone" of all the
// subtypes. In general a read of a cone type (as opposed to an exact type) will
// require N incoming links, from each of the N subtypes - and we need that
// for each struct.get of a cone. If there are M such gets then we have N * M
// edges for this. Instead, we make a single canonical "cone read" location, and
// add a single link to it from each get, which is only N + M (plus the cost
// of adding "latency" in requiring an additional step along the way for the
// data to flow along).
struct ConeReadLocation {
  HeapType type;
  // The index of the field in a struct, or 0 for an array (where we do not
  // attempt to differentiate by index).
  Index index;
  bool operator==(const ConeReadLocation& other) const {
    return type == other.type && index == other.index;
  }
};

// A location is a variant over all the possible flavors of locations that we
// have.
using Location = std::variant<ExpressionLocation,
                              ResultLocation,
                              LocalLocation,
                              BreakTargetLocation,
                              GlobalLocation,
                              SignatureParamLocation,
                              SignatureResultLocation,
                              DataLocation,
                              TagLocation,
                              NullLocation,
                              ConeReadLocation>;

} // namespace wasm

namespace std {

std::ostream& operator<<(std::ostream& stream,
                         const wasm::PossibleContents& contents);

template<> struct hash<wasm::PossibleContents> {
  size_t operator()(const wasm::PossibleContents& contents) const {
    return contents.hash();
  }
};

// Define hashes of all the *Location flavors so that Location itself is
// hashable and we can use it in unordered maps and sets.

template<> struct hash<wasm::ExpressionLocation> {
  size_t operator()(const wasm::ExpressionLocation& loc) const {
    return std::hash<std::pair<size_t, wasm::Index>>{}(
      {size_t(loc.expr), loc.tupleIndex});
  }
};

template<> struct hash<wasm::ResultLocation> {
  size_t operator()(const wasm::ResultLocation& loc) const {
    return std::hash<std::pair<size_t, wasm::Index>>{}(
      {size_t(loc.func), loc.index});
  }
};

template<> struct hash<wasm::LocalLocation> {
  size_t operator()(const wasm::LocalLocation& loc) const {
    return std::hash<std::pair<size_t, std::pair<wasm::Index, wasm::Index>>>{}(
      {size_t(loc.func), {loc.index, loc.tupleIndex}});
  }
};

template<> struct hash<wasm::BreakTargetLocation> {
  size_t operator()(const wasm::BreakTargetLocation& loc) const {
    return std::hash<std::pair<size_t, std::pair<wasm::Name, wasm::Index>>>{}(
      {size_t(loc.func), {loc.target, loc.tupleIndex}});
  }
};

template<> struct hash<wasm::GlobalLocation> {
  size_t operator()(const wasm::GlobalLocation& loc) const {
    return std::hash<wasm::Name>{}(loc.name);
  }
};

template<> struct hash<wasm::SignatureParamLocation> {
  size_t operator()(const wasm::SignatureParamLocation& loc) const {
    return std::hash<std::pair<wasm::HeapType, wasm::Index>>{}(
      {loc.type, loc.index});
  }
};

template<> struct hash<wasm::SignatureResultLocation> {
  size_t operator()(const wasm::SignatureResultLocation& loc) const {
    return std::hash<std::pair<wasm::HeapType, wasm::Index>>{}(
      {loc.type, loc.index});
  }
};

template<> struct hash<wasm::DataLocation> {
  size_t operator()(const wasm::DataLocation& loc) const {
    return std::hash<std::pair<wasm::HeapType, wasm::Index>>{}(
      {loc.type, loc.index});
  }
};

template<> struct hash<wasm::TagLocation> {
  size_t operator()(const wasm::TagLocation& loc) const {
    return std::hash<std::pair<wasm::Name, wasm::Index>>{}(
      {loc.tag, loc.tupleIndex});
  }
};

template<> struct hash<wasm::NullLocation> {
  size_t operator()(const wasm::NullLocation& loc) const {
    return std::hash<wasm::Type>{}(loc.type);
  }
};

template<> struct hash<wasm::ConeReadLocation> {
  size_t operator()(const wasm::ConeReadLocation& loc) const {
    return std::hash<std::pair<wasm::HeapType, wasm::Index>>{}(
      {loc.type, loc.index});
  }
};

} // namespace std

namespace wasm {

// Analyze the entire wasm file to find which contents are possible in which
// locations. This assumes a closed world and starts from roots - newly created
// values - and propagates them to the locations they reach. After the
// analysis the user of this class can ask which contents are possible at any
// location.
//
// This focuses on useful information for the typical user of this API.
// Specifically, we find out:
//
//  1. What locations have no content reaching them at all. That means the code
//     is unreachable. (Other passes may handle this, but ContentOracle does it
//     for all things, so it might catch situations other passes do not cover;
//     and, it takes no effort to support this here).
//  2. For all locations, we try to find when they must contain a constant value
//     like i32(42) or ref.func(foo).
//  3. For locations that contain references, information about the subtypes
//     possible there. For example, if something has wasm type anyref in the IR,
//     we might find it must contain an exact type of something specific.
//
// Note that there is not much use in providing type info for locations that are
// *not* references. If a local is i32, for example, then it cannot contain any
// subtype anyhow, since i32 is not a reference and has no subtypes. And we know
// the type i32 from the wasm anyhow, that is, the caller will know it.
// Therefore the only useful information we can provide on top of the info
// already in the wasm is either that nothing can be there (1, above), or that a
// constant must be there (2, above), and so we do not make an effort to track
// non-reference types here. This makes the internals of ContentOracle simpler
// and faster. A noticeable outcome of that is that querying the contents of an
// i32 local will return Many and not ExactType{i32} (assuming we could not
// infer either that there must be nothing there, or a constant). Again, the
// caller is assumed to know the wasm IR type anyhow, and also other
// optimization passes work on the types in the IR, so we do not focus on that
// here.
class ContentOracle {
  Module& wasm;

  void analyze();

public:
  ContentOracle(Module& wasm) : wasm(wasm) { analyze(); }

  // Get the contents possible at a location.
  PossibleContents getContents(Location location) {
    auto iter = locationContents.find(location);
    if (iter == locationContents.end()) {
      // We know of no possible contents here.
      return PossibleContents::none();
    }
    return iter->second;
  }

private:
  std::unordered_map<Location, PossibleContents> locationContents;
};

} // namespace wasm

#endif // wasm_ir_possible_contents_h