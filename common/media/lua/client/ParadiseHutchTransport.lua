-- Add inside the existing Paradise package. No Java client installation.
if not isClient() then return end
if ParadiseHutchTransportClient then return end
local runtime=require 'ParadiseHutchTransport/ClientRuntime'
local coordinator=require 'ParadiseHutchTransport/Coordinator'
local membership=require 'ParadiseHutchTransport/Membership'
local hydration=require 'ParadiseHutchTransport/Hydration'
local corpses=require 'ParadiseHutchTransport/Corpses'
local bootstrap=require 'ParadiseHutchTransport/Bootstrap'
local cache=require 'ParadiseHutchTransport/NestCache'
require 'ParadiseHutchCorpseGuard'
ParadiseHutchTransportClient=runtime({coordinator=function()
    local b=bootstrap()
    return coordinator(membership,hydration,{makeCorpses=corpses,makeCache=cache,bootstrapAtHutch=function(h,item,pid,oid) return b.create(h,item,pid,oid) end})
end})
ParadiseHutchTransportClient.install()
