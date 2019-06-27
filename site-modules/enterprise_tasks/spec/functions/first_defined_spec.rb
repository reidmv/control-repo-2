require 'spec_helper'

describe 'enterprise_tasks::first_defined' do

  it do
    is_expected.to run.with_params.and_return(nil)
  end

  it do
    is_expected.to run.with_params('defined').and_return('defined')
  end

  it do
    is_expected.to run.with_params(nil).and_return(nil)
  end

  it do
    is_expected.to run.with_params(nil, 'defined').and_return('defined')
  end

  it do
    is_expected.to run.with_params('', 'defined').and_return('defined')
  end
end
