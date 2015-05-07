require 'spec_helper'
require 'hash'

describe Hash do
  context '#supermerge' do
    it 'should complain unless two hashes are passed to it' do
      expect { {}.supermerge('y') }.to raise_error(RuntimeError)
    end

    it 'should merge two simple hashes' do
      expect({ a: 'x' }.supermerge(b: 'y')).to eq(a: 'x', b: 'y')
    end

    it 'should merge two hashes both with arrays at the same key' do
      expect({ a: ['x'] }.supermerge(a: ['y'])).to eq(a: %w(x y))
    end

    it 'should merge an array and a value at the same key' do
      expect({ a: 'x' }.supermerge(a: ['y'])).to eq(a: %w(x y))
    end

    it 'should replace a value at the same key' do
      expect({ a: 'x' }.supermerge(a: 'y')).to eq(a: 'y')
    end

    it 'should merge two subhashes at the same key' do
      expect({ a: { b: 'x' } }.supermerge(a: { c: 'y' })).to eq(a: { b: 'x', c: 'y' })
    end
  end
end
