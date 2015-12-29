module countingfilter;

import std.conv : to;

immutable KEY_SIZE = 12;
immutable ARRAY_SIZE = 1 << KEY_SIZE;
immutable KEY_MASK = (1 << KEY_SIZE) - 1;
immutable KEY_SHIFT = 16;


class CountingFilter
{
private:
  ubyte[ARRAY_SIZE] counters;

  ubyte* firstSlot(uint hash) @nogc nothrow pure @safe
  {
    return &(counters[hash1(hash)]);
  }

  ubyte* secondSlot(uint hash) @nogc nothrow pure @safe
  {
    return &(counters[hash2(hash)]);
  }

public:

  void clear() @nogc nothrow pure @safe
  {
    counters = (ubyte[ARRAY_SIZE]).init;
  }

  void insert(T)(T elem) pure @safe
    if ( __traits(isIntegral, T) )
  {
    ubyte* slot1 = firstSlot(bloomHash!T(elem));
    if (!full(slot1)) ++*slot1;
    ubyte* slot2 = secondSlot(bloomHash!T(elem));
    if (!full(slot2)) ++*slot2;

  }

  void remove(T)(T elem) pure @safe
    if ( __traits(isIntegral, T) )
  {
    ubyte* slot1 = firstSlot(bloomHash!T(elem));
    if (!full(slot1)) --*slot1;
    ubyte* slot2 = secondSlot(bloomHash!T(elem));
    if (!full(slot2)) --*slot2;
  }

  bool mightContain(T)(T elem) pure @safe
    if ( __traits(isIntegral, T) )
  {
    return *firstSlot(bloomHash!T(elem)) != 0 && *secondSlot(bloomHash!T(elem)) != 0;
  }
}


uint bloomHash(T)(T elem) pure @safe
  if ( __traits(isIntegral, T) )
{
  return ((elem >> 32) ^ elem).to!uint;
}


bool full(in ubyte* slot) @nogc nothrow pure @safe
{
  return *slot == 0xff;
}


uint hash1(uint hash) @nogc nothrow pure @safe
{
  return hash & KEY_MASK;
}


uint hash2(uint hash) @nogc nothrow pure @safe
{
  return (hash >> KEY_SHIFT) & KEY_MASK;
}


unittest
{
  import std.algorithm : filter, count;
  import std.range : iota;

  auto cf = new CountingFilter;

  foreach (i; 0UL..1000)
    cf.insert(i);

  foreach (i; 0UL..1000)
    assert(cf.mightContain(i));

  auto falsePositive = 1001UL.iota(2000).filter!(a => cf.mightContain(a)).count;
  assert(falsePositive < 10);  // 1%.

  foreach (i; 0UL..100)
    cf.remove(i);

  foreach(i; 100UL..1000)
    assert(cf.mightContain(i));

  falsePositive = 0UL.iota(100).filter!(a => cf.mightContain(a)).count;
  assert(falsePositive < 2);  // 2%.

  cf.clear;

  foreach (i; 0UL..2000)
    assert(!cf.mightContain(i));
}
