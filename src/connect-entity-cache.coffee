crypto = require "crypto"
inferHeaders = require "infer-entity-headers"

module.exports = class ConnectEntityCache
  constructor: (options = {}) ->
    @cache = {}
    @log = options.log or (msg) ->
    @warn = options.warn or console.warn
  
  cacheEntity: (path, entity, headers) ->
    @log "Caching #{path}"
    entity = new Buffer entity if typeof entity is "string"
    unless entity instanceof Buffer
      throw new Error "Entity must either be a buffer or a string. #{entity}"
    if headers["content-length"] and headers["content-length"] isnt String(entity.length)
      @warn "content-length header (#{headers["content-length"]}) does not match entity length (#{entity.length})"
    headers = inferHeaders path, entity, headers
    @cache[path] =
      path: path
      headers: headers
      entity: entity
      lastModified: new Date headers['last-modified']
      eTag: headers['etag']

  handle: (req, res, next) =>
    return next() unless data = @cache[req.url]
    switch req.method
      when "OPTIONS" then handleOptions req, res, next 
      when "GET", "HEAD" then @handleProper data, req, res, next
      else @handleNonGet req, res, next
  
  handleOptions: (req, res, next) ->
    res.statusCode = 200
    res.setHeader "Allow", "OPTIONS, GET, HEAD"
    res.end ""
    
  handleProper: (data, req, res, next) ->
    if isModified data, req.headers
      res.statusCode = 200
      res.setHeader name, value for name, value of data.headers
      res.end if req.method is "GET" then data.entity else ""
    else
      res.statusCode = 304
      res.setHeader name, value for name, value of data.headers when name isnt "content-length"
      res.end ""
    @log "#{res.statusCode}: #{data.path}"

  handleNotAllowed: (req, res, next) ->
    res.statusCode = 405
    res.setHeader "Allow", "OPTIONS, GET, HEAD"
    res.setHeader "Content-Type", "text/plain"
    res.end "You can only GET this resource."
    res.end()
  
isModified = (data, headers) ->
  return true unless headers['if-modified-since']? or headers['if-none-match']?
  if headers['if-modified-since']?
    if data.lastModified > new Date headers['if-modified-since']
      return true 
  if headers['if-none-match']?
    return true if data.eTag isnt headers['if-none-match']
  return false