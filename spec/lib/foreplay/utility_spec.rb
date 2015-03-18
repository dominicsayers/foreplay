require 'spec_helper'
require 'foreplay'

describe Foreplay::Utility do
  it 'should complain unless two hashes are passed to it' do
    expect { Foreplay::Utility.supermerge('x', 'y') }.to raise_error(RuntimeError)
  end

  it 'should merge two simple hashes' do
    expect(Foreplay::Utility.supermerge({ a: 'x' }, b: 'y')).to eq('a' => 'x', 'b' => 'y')
  end

  it 'should merge two hashes both with arrays at the same key' do
    expect(Foreplay::Utility.supermerge({ a: ['x'] }, a: ['y'])).to eq('a' => %w(x y))
  end

  it 'should merge an array and a value at the same key' do
    expect(Foreplay::Utility.supermerge({ a: 'x' }, a: ['y'])).to eq('a' => %w(x y))
  end

  it 'should replace a value at the same key' do
    expect(Foreplay::Utility.supermerge({ a: 'x' }, a: 'y')).to eq('a' => 'y')
  end

  it 'should merge two subhashes at the same key' do
    expect(Foreplay::Utility.supermerge({ a: { b: 'x' } }, a: { c: 'y' })).to eq('a' => { 'b' => 'x', 'c' => 'y' })
  end
end
