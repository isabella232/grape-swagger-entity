require 'spec_helper'

describe 'responseModel' do
  before :all do
    module ThisApi
      module Entities
        class Kind < Grape::Entity
          expose :title, documentation: { type: 'string', desc: 'Title of the kind.' }
        end

        class Relation < Grape::Entity
          expose :name, documentation: { type: 'string', desc: 'Name' }
        end
        class Tag < Grape::Entity
          expose :name, documentation: { type: 'string', desc: 'Name' }
        end
        class Error < Grape::Entity
          expose :code, documentation: { type: 'string', desc: 'Error code' }
          expose :message, documentation: { type: 'string', desc: 'Error message' }
        end

        class Something < Grape::Entity
          expose :text, documentation: { type: 'string', desc: 'Content of something.' }
          expose :colors, documentation: { type: 'string', desc: 'Colors', is_array: true }
          expose :kind, using: Kind, documentation: { type: 'ThisApi::Kind', desc: 'The kind of this something.' }
          expose :kind2, using: Kind, documentation: { desc: 'Secondary kind.' }
          expose :kind3, using: ThisApi::Entities::Kind, documentation: { desc: 'Tertiary kind.' }
          expose :tags, using: ThisApi::Entities::Tag, documentation: { desc: 'Tags.', is_array: true }
          expose :relation, using: ThisApi::Entities::Relation, documentation: { type: 'ThisApi::Relation', desc: 'A related model.' }
        end
      end

      class ResponseModelApi < Grape::API
        format :json
        desc 'This returns something',
             is_array: true,
             http_codes: [{ code: 200, message: 'OK', model: Entities::Something }]
        get '/something' do
          something = OpenStruct.new text: 'something'
          present something, with: Entities::Something
        end

        # something like an index action
        desc 'This returns something or an error',
             entity: Entities::Something,
             http_codes: [
               { code: 200, message: 'OK', model: Entities::Something },
               { code: 403, message: 'Refused to return something', model: Entities::Error }
             ]
        params do
          optional :id, type: Integer
        end
        get '/something/:id' do
          if params[:id] == 1
            something = OpenStruct.new text: 'something'
            present something, with: Entities::Something
          else
            error = OpenStruct.new code: 'some_error', message: 'Some error'
            present error, with: Entities::Error
          end
        end

        add_swagger_documentation
      end
    end
  end

  def app
    ThisApi::ResponseModelApi
  end

  subject do
    get '/swagger_doc/something'
    JSON.parse(last_response.body)
  end

  it 'documents index action' do
    expect(subject['paths']['/something']['get']['responses']).to eq(
      '200' => {
        'description' => 'OK',
        'schema' => {
          'type' => 'array',
          'items' => { '$ref' => '#/definitions/Something' }
        }
      }
    )
  end

  it 'should document specified models as show action' do
    expect(subject['paths']['/something/{id}']['get']['responses']).to eq(
      '200' => {
        'description' => 'OK',
        'schema' => { '$ref' => '#/definitions/Something' }
      },
      '403' => {
        'description' => 'Refused to return something',
        'schema' => { '$ref' => '#/definitions/Error' }
      }
    )
    expect(subject['definitions'].keys).to include 'Error'
    expect(subject['definitions']['Error']).to eq(
      'type' => 'object',
      'description' => 'This returns something or an error',
      'properties' => {
        'code' => { 'type' => 'string', 'description' => 'Error code' },
        'message' => { 'type' => 'string', 'description' => 'Error message' }
      }
    )

    expect(subject['definitions'].keys).to include 'Something'
    expect(subject['definitions']['Something']).to eq(
      'type' => 'object',
      'description' => 'This returns something or an error',
      'properties' =>
          { 'text' => { 'type' => 'string', 'description' => 'Content of something.' },
            'colors' => { 'type' => 'array', 'items' => { 'type' => 'string' }, 'description' => 'Colors' },
            'kind' => { '$ref' => '#/definitions/Kind', 'description' => 'The kind of this something.' },
            'kind2' => { '$ref' => '#/definitions/Kind', 'description' => 'Secondary kind.' },
            'kind3' => { '$ref' => '#/definitions/Kind', 'description' => 'Tertiary kind.' },
            'tags' => { 'type' => 'array', 'items' => { '$ref' => '#/definitions/Tag' }, 'description' => 'Tags.' },
            'relation' => { '$ref' => '#/definitions/Relation', 'description' => 'A related model.' } }
    )

    expect(subject['definitions'].keys).to include 'Kind'
    expect(subject['definitions']['Kind']).to eq(
      'type' => 'object', 'properties' => { 'title' => { 'type' => 'string', 'description' => 'Title of the kind.' } }
    )

    expect(subject['definitions'].keys).to include 'Relation'
    expect(subject['definitions']['Relation']).to eq(
      'type' => 'object', 'properties' => { 'name' => { 'type' => 'string', 'description' => 'Name' } }
    )

    expect(subject['definitions'].keys).to include 'Tag'
    expect(subject['definitions']['Tag']).to eq(
      'type' => 'object', 'properties' => { 'name' => { 'type' => 'string', 'description' => 'Name' } }
    )
  end
end

describe 'building definitions from given entities' do
  before :all do
    module TheseApi
      module Entities
        class Kind < Grape::Entity
          expose :id, documentation: { type: Integer, desc: 'Title of the kind.', values: [1, 2] }
        end

        class Relation < Grape::Entity
          expose :name, documentation: { type: String, desc: 'Name' }
        end
        class Tag < Grape::Entity
          expose :name, documentation: { type: 'string', desc: 'Name' }
        end

        class SomeEntity < Grape::Entity
          expose :text, documentation: { type: 'string', desc: 'Content of something.' }
          expose :kind, using: Kind, documentation: { type: 'TheseApi::Kind', desc: 'The kind of this something.' }
          expose :kind2, using: Kind, documentation: { desc: 'Secondary kind.' }
          expose :kind3, using: TheseApi::Entities::Kind, documentation: { desc: 'Tertiary kind.' }
          expose :tags, using: TheseApi::Entities::Tag, documentation: { desc: 'Tags.', is_array: true }
          expose :relation, using: TheseApi::Entities::Relation, documentation: { type: 'TheseApi::Relation', desc: 'A related model.' }
        end
      end

      class ResponseEntityApi < Grape::API
        format :json
        desc 'This returns something',
             is_array: true,
             entity: Entities::SomeEntity
        get '/some_entity' do
          something = OpenStruct.new text: 'something'
          present something, with: Entities::SomeEntity
        end

        add_swagger_documentation
      end
    end
  end

  def app
    TheseApi::ResponseEntityApi
  end

  subject do
    get '/swagger_doc'
    JSON.parse(last_response.body)
  end

  it 'prefers entity over other `using` values' do
    expect(subject['definitions']).to eql(
      'Kind' => {
        'type' => 'object',
        'properties' => {
          'id' => { 'type' => 'integer', 'format' => 'int32', 'description' => 'Title of the kind.', 'enum' => [1, 2] }
        }
      },
      'Tag' => { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string', 'description' => 'Name' } } },
      'Relation' => { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string', 'description' => 'Name' } } },
      'SomeEntity' => {
        'type' => 'object',
        'properties' => {
          'text' => { 'type' => 'string', 'description' => 'Content of something.' },
          'kind' => { '$ref' => '#/definitions/Kind', 'description' => 'The kind of this something.' },
          'kind2' => { '$ref' => '#/definitions/Kind', 'description' => 'Secondary kind.' },
          'kind3' => { '$ref' => '#/definitions/Kind', 'description' => 'Tertiary kind.' },
          'tags' => { 'type' => 'array', 'items' => { '$ref' => '#/definitions/Tag' }, 'description' => 'Tags.' },
          'relation' => { '$ref' => '#/definitions/Relation', 'description' => 'A related model.' }
        },
        'description' => 'This returns something'
      }
    )
  end
end
