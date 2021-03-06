--- Module which provide Service type
--
-- *Dependencies:* `atf.util`, `function_id`, `json`, `protocol_handler.ford_protocol_constants`, `events`, `expectations`
--
-- *Globals:* `xmlReporter`
-- @module services.control_service
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

require('atf.util')

local functionId = require('function_id')
local json = require('json')
local constants = require('protocol_handler/ford_protocol_constants')
local events = require('events')
local Event = events.Event
local expectations = require('expectations')

local Expectation = expectations.Expectation
local SUCCESS = expectations.SUCCESS
local FAILED = expectations.FAILED

local ControlService = {}
local mt = { __index = { } }

--- Type which represents control service
-- @type Service

--- Construct instance of Service type
-- @tparam MobileSession session Mobile session
-- @treturn Service Constructed instance
function ControlService.Service(session)
  local res = { }
  res.session = session
  setmetatable(res, mt)
  return res
end

--- Send message with control frame
-- @tparam table message Message
-- @treturn table Message
function mt.__index:Send(message)
  message.frameType = constants.FRAME_TYPE.CONTROL_FRAME
  self.session:Send(message)
  xmlReporter.AddMessage("mobile_connection","Send",{message})
  return message
end

--- Send message with control frame and control service type
-- @tparam table message Service message
-- @treturn table Service message
function mt.__index:SendControlMessage(message)
  message.frameType = constants.FRAME_TYPE.CONTROL_FRAME
  message.serviceType = constants.SERVICE_TYPE.CONTROL
  self:Send(message)
  return message
end

--- Start service and create expectation on this event
-- @tparam number service type of service
-- @treturn Expectation Expectation on start service event
function mt.__index:StartService(service)
  xmlReporter.AddMessage("StartService", service)
  local startSession =
  {
    serviceType = service,
    frameInfo =  constants.FRAME_INFO.START_SERVICE,
    sessionId = self.session.sessionId.get(),
  }
  -- prepare event to expect
  local startserviceEvent = Event()
  startserviceEvent.matches = function(_, data)
    return data.frameType == 0 and
    data.serviceType == service and
    (service == constants.SERVICE_TYPE.RPC or data.sessionId == self.session.sessionId.get()) and
    (data.frameInfo == constants.FRAME_INFO.START_SERVICE_ACK or
      data.frameInfo == constants.FRAME_INFO.START_SERVICE_NACK)
  end
  self:Send(startSession)

  local ret = self.session:ExpectEvent(startserviceEvent, "StartService ACK")
  :ValidIf(function(s, data)
      if data.frameInfo == constants.FRAME_INFO.START_SERVICE_ACK then
        xmlReporter.AddMessage("StartService", "StartService ACK", "True")
        return true
      else return false, "StartService NACK received" end
    end)
  return ret
end

--- Stop service and create expectation on this event
-- @tparam number service type of service
-- @treturn Expectation Expectation on end service event
function mt.__index:StopService(service)
  assert(self.session.hashCode ~= 0, "StartServiceAck was not received. Unable to stop not started service")
  xmlReporter.AddMessage("StopService", service)
  local stopService =
  self:Send(
    {
      serviceType = service,
      frameInfo = constants.FRAME_INFO.END_SERVICE,
      sessionId = self.session.sessionId.get(),
      binaryData = self.session.hashCode,
    })
  local event = Event()
  -- prepare event to expect
  event.matches = function(_, data)
    return data.frameType == constants.FRAME_TYPE.CONTROL_FRAME and
    data.serviceType == service and
    (service == constants.SERVICE_TYPE.RPC or data.sessionId == self.session.sessionId.get()) and
    (data.frameInfo == constants.FRAME_INFO.END_SERVICE_ACK or
      data.frameInfo == constants.FRAME_INFO.END_SERVICE_NACK)
  end

  local ret = self.session:ExpectEvent(event, "EndService ACK")
  :ValidIf(function(s, data)
      if data.frameInfo == constants.FRAME_INFO.END_SERVICE_ACK then return true
      else return false, "EndService NACK received" end
    end)
  return ret
end

return ControlService
