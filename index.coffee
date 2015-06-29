async = require 'async'
_ = require 'lodash'
request = require 'request'
MeshbluConfig = require 'meshblu-config'
meshbluConfig = new MeshbluConfig
Meshblu = require 'meshblu'

meshblu = Meshblu.createConnection meshbluConfig.toJSON()

meshblu.on 'ready', ->
  console.log 'ready'

meshblu.on 'notReady', (data) ->
  console.log 'notReady', data

generateAndForwardMeshbluCredentials = (device, options, callback=->) =>
  return callback() unless options.generateAndForwardMeshbluCredentials
  meshblu.generateAndStoreToken device, (data) =>
    return callback error if error?
    callback null, data.token

meshblu.on 'message', (message) ->
  meshblu.whoami {}, (device) ->
    messageHooks = device.meshblu?.messageHooks
    async.eachSeries messageHooks, (options, callback=->) =>
      generateAndForwardMeshbluCredentials device, options, (error, token) =>
        options = _.extend {}, _.omit(options, 'generateAndForwardMeshbluCredentials'), json: message, rejectUnauthorized: false
        options.auth ?= bearer: new Buffer("#{device.uuid}:#{token}").toString('base64') if token
        options.proxy ?= process.env.PROXY if process.env.PROXY?
        request options, (error, response, body) =>
          meshblu.revokeToken(uuid: device.uuid, token: token) if token?
          callback()
          return console.error error if error?
          return console.error new Error "HTTP Status: #{response.statusCode}" unless _.inRange response.statusCode, 200, 300
          console.log body
