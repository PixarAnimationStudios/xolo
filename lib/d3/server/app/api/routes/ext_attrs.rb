module D3

  # These routes are only for working with
  # policies in the JSS
  #
  module Server
 class App < Sinatra::Base

    EAS_ROUTE_BASE = "#{API_V1_ROUTE_BASE}/ext_attrs".freeze

    namespace EAS_ROUTE_BASE do
      # pacakges namespace

      # the summary list
      get '' do
        D3::ExtensionAttribute.json_summary_list
      end

      # the summary list
      get '/nonpatch' do
        JSS::ComputerExtensionAttribute.all_names.to_json
      end

      # create a new title
      post '/:ea' do
        halt_if_ea_already_exists! params[:ea]
        ea_object = D3::ExtensionAttribute.new_from_client_json request.body.read
        ea_object.create
        { status: :ok, message: :created }.to_json
      end

      # get a title
      get '/:ea' do
        halt_if_ea_not_found! params[:ea]
        D3::ExtensionAttribute.fetch(params[:ea]).to_json
      end

      # update a title
      put '/:ea' do
        halt_if_ea_not_found! params[:ea]
        ea_object = D3::ExtensionAttribute.new_from_client_json request.body.read
        ea_object.update
        { status: :ok, message: :updated }.to_json
      end

      # delete a title
      delete '/:ea' do
        halt_if_ea_not_ExtensionAttributefound! params[:ea]
        ea_object = D3::ExtensionAttribute.fetch(params[:ea])
        ea_object.delete
        { status: :ok, message: 'deleted' }.to_json
      end

    end # namespace

  end # class App 
 end # module Server

end # module D3
