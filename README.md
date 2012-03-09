# shoulda-matchers [![Build Status](https://secure.travis-ci.org/thoughtbot/shoulda-matchers.png?branch=master)](http://travis-ci.org/thoughtbot/shoulda-matchers)

[Official Documentation](http://rubydoc.info/github/thoughtbot/shoulda-matchers/master/frames)

Test::Unit- and RSpec-compatible one-liners that test common Rails functionality.
These tests would otherwise be much longer, more complex, and error-prone.

Refer to the [shoulda](https://github.com/thoughtbot/shoulda) gem if you want to know more
about using shoulda with Test::Unit.

Please report bugs on the [shoulda issue tracker](https://github.com/thoughtbot/shoulda/issues).

## ActiveRecord Matchers

Matchers to test associations:

    describe Post do
      it { should belong_to(:user) }
      it { should have_many(:tags).through(:taggings) }
    end

    describe User do
      it { should have_many(:posts) }
    end

## ActiveModel Matchers

Matchers to test validations and mass assignments:

    describe Post do
      it { should validate_uniqueness_of(:title) }
      it { should validate_presence_of(:body).with_message(/wtf/) }
      it { should validate_presence_of(:title) }
      it { should validate_numericality_of(:user_id) }
    end

    describe User do
      it { should_not allow_value("blah").for(:email) }
      it { should allow_value("a@b.com").for(:email) }
      it { should ensure_inclusion_of(:age).in_range(1..100) }
      it { should_not allow_mass_assignment_of(:password) }
    end

## ActionController Matchers

Matchers to test common patterns:

    describe PostsController, "#show" do
      context "for a fictional user" do
        before do
          get :show, :id => 1
        end

        it { should assign_to(:user) }
        it { should respond_with(:success) }
        it { should render_template(:show) }
        it { should_not set_the_flash }
      end
    end

## Installation

In Rails 3 and Bundler, add the following to your Gemfile:

    group :test do
      gem "rspec-rails"
      gem "shoulda-matchers"
    end

Shoulda will automatically include matchers into the appropriate example groups.

## Credits

Shoulda is maintained and funded by [thoughtbot](http://thoughtbot.com/community).
Thank you to all the [contributors](https://github.com/thoughtbot/shoulda-matchers/contributors).

## License

Shoulda is Copyright © 2006-2010 thoughtbot, inc.
It is free software, and may be redistributed under the terms specified in the MIT-LICENSE file.
