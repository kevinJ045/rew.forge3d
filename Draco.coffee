{ BufferAttribute, BufferGeometry, Color, FileLoader, Loader, LinearSRGBColorSpace, SRGBColorSpace } = require 'three'

_taskCache = new WeakMap()

class DRACOLoader extends Loader

	constructor: (manager) ->
		super(manager)

		@decoderPath = ''
		@decoderConfig = {}
		@decoderBinary = null
		@decoderPending = null

		@workerLimit = 4
		@workerPool = []
		@workerNextTaskID = 1
		@workerSourceURL = ''

		@defaultAttributeIDs = {
			position: 'POSITION'
			normal: 'NORMAL'
			color: 'COLOR'
			uv: 'TEX_COORD'
		}
		@defaultAttributeTypes =
			position: 'Float32Array'
			normal: 'Float32Array'
			color: 'Float32Array'
			uv: 'Float32Array'
		@

	setDecoderPath: (path) ->
		@decoderPath = path
		@

	setDecoderConfig: (config) ->
		@decoderConfig = config
		@

	setWorkerLimit: (workerLimit) ->
		@workerLimit = workerLimit
		@

	load: (url, onLoad, onProgress, onError) ->
		loader = new FileLoader(@manager)
		loader.setPath(@path)
		loader.setResponseType('arraybuffer')
		loader.setRequestHeader(@requestHeader)
		loader.setWithCredentials(@withCredentials)
		loader.load(url, (buffer) =>
			@parse(buffer, onLoad, onError)
		, onProgress, onError)

	parse: (buffer, onLoad, onError) ->
		@decodeDracoFile(buffer, onLoad, null, null, SRGBColorSpace).catch(onError)

	decodeDracoFile: (buffer, callback, attributeIDs, attributeTypes, vertexColorSpace = LinearSRGBColorSpace) ->
		taskConfig =
			attributeIDs: attributeIDs or @defaultAttributeIDs
			attributeTypes: attributeTypes or @defaultAttributeTypes
			useUniqueIDs: !!attributeIDs
			vertexColorSpace: vertexColorSpace
		@decodeGeometry(buffer, taskConfig).then(callback)

	decodeGeometry: (buffer, taskConfig) ->
		taskKey = JSON.stringify(taskConfig)

		if _taskCache.has(buffer)
			cachedTask = _taskCache.get(buffer)
			if cachedTask.key is taskKey
				return cachedTask.promise
			else if buffer.byteLength is 0
				throw new Error(
					'THREE.DRACOLoader: Unable to re-decode a buffer with different settings. Buffer has already been transferred.'
				)

		let worker
		taskID = @workerNextTaskID++
		taskCost = buffer.byteLength

		geometryPending = @._getWorker(taskID, taskCost)
			.then((_worker) ->
				worker = _worker
				new Promise((resolve, reject) ->
					worker._callbacks[taskID] = { resolve, reject }
					worker.postMessage(type: 'decode', id: taskID, taskConfig, buffer), [buffer]
				)
			)
			.then((message) => @._createGeometry(message.geometry))

		geometryPending
			.catch(() => true)
			.then(() =>
				if worker and taskID
					@._releaseTask(worker, taskID)
			)

		_taskCache.set(buffer, key: taskKey, promise: geometryPending)

		geometryPending

	_createGeometry: (geometryData) ->
		geometry = new BufferGeometry()
		if geometryData.index
			geometry.setIndex(new BufferAttribute(geometryData.index.array, 1))
		for result in geometryData.attributes
			name = result.name
			array = result.array
			itemSize = result.itemSize
			attribute = new BufferAttribute(array, itemSize)
			if name is 'color'
				@._assignVertexColorSpace(attribute, result.vertexColorSpace)
				attribute.normalized = array instanceof Float32Array is false
			geometry.setAttribute(name, attribute)
		geometry

	_assignVertexColorSpace: (attribute, inputColorSpace) ->
		return if inputColorSpace isnt SRGBColorSpace
		_color = new Color()
		for i in [0...attribute.count]
			_color.fromBufferAttribute(attribute, i).convertSRGBToLinear()
			attribute.setXYZ(i, _color.r, _color.g, _color.b)

	_loadLibrary: (url, responseType) ->
		loader = new FileLoader(@manager)
		loader.setPath(@decoderPath)
		loader.setResponseType(responseType)
		loader.setWithCredentials(@withCredentials)
		new Promise((resolve, reject) ->
			loader.load(url, resolve, undefined, reject)
		)

	preload: ->
		@._initDecoder()
		@

	_initDecoder: ->
		return @decoderPending if @decoderPending
		useJS = typeof WebAssembly isnt 'object' or @decoderConfig.type is 'js'
		librariesPending = []
		if useJS
			librariesPending.push(@._loadLibrary('draco_decoder.js', 'text'))
		else
			librariesPending.push(@._loadLibrary('draco_wasm_wrapper.js', 'text'))
			librariesPending.push(@._loadLibrary('draco_decoder.wasm', 'arraybuffer'))
		@decoderPending = Promise.all(librariesPending)
			.then((libraries) =>
				jsContent = libraries[0]
				@decoderConfig.wasmBinary = libraries[1] unless useJS
				fn = DRACOWorker.toString()
				body = [
					'/* draco decoder */'
					jsContent
					''
					'/* worker */'
					fn.substring(fn.indexOf('{') + 1, fn.lastIndexOf('}'))
				].join('\n')
				@workerSourceURL = new URL("data:text/javascript;utf8,#{escape(body)}")
			)
		@decoderPending

	_getWorker: (taskID, taskCost) ->
		@._initDecoder().then(() =>
			if @workerPool.length < @workerLimit
				worker = new global.Worker(@workerSourceURL)
				worker._callbacks = {}
				worker._taskCosts = {}
				worker._taskLoad = 0
				worker.postMessage(type: 'init', decoderConfig: @decoderConfig)
				worker.on 'message', (e) ->
					message = e
					switch message.type
						when 'decode' then worker._callbacks[message.id].resolve(message)
						when 'error' then worker._callbacks[message.id].reject(message)
						else console.error("THREE.DRACOLoader: Unexpected message, '#{message.type}'")
				@workerPool.push(worker)
			else
				@workerPool.sort((a, b) -> if a._taskLoad > b._taskLoad then -1 else 1)
			worker = @workerPool[@workerPool.length - 1]
			worker._taskCosts[taskID] = taskCost
			worker._taskLoad += taskCost
			worker
		)

	_releaseTask: (worker, taskID) ->
		worker._taskLoad -= worker._taskCosts[taskID]
		delete worker._callbacks[taskID]
		delete worker._taskCosts[taskID]

	debug: ->
		console.log('Task load: ', @workerPool.map((worker) -> worker._taskLoad))

	dispose: ->
		for worker in @workerPool
			worker.terminate()
		@workerPool.length = 0
		if @workerSourceURL isnt ''
			URL.revokeObjectURL(@workerSourceURL)
		@

# WEB WORKER

DRACOWorker = ->
	decoderConfig = null
	decoderPending = null
	{ parentPort } = require 'worker_threads'
	global.self = global
	global.globalThis = global
	parentPort.on 'message', (e) ->
		message = e
		buffer = message.buffer
		taskConfig = message.taskConfig
		switch message.type
			when 'init'
				decoderConfig = message.decoderConfig
				decoderPending = new Promise((resolve) ->
					decoderConfig.onModuleLoaded = (draco) ->
						resolve(draco: draco)
					DracoDecoderModule(decoderConfig) # eslint-disable-line no-undef
				)
			when 'decode'
				decoderPending.then((module) ->
					draco = module.draco
					decoder = new draco.Decoder()
					try
						geometry = decodeGeometry(draco, decoder, new Int8Array(buffer), taskConfig)
						buffers = geometry.attributes.map((attr) -> attr.array.buffer)
						buffers.push(geometry.index.array.buffer) if geometry.index
						parentPort.postMessage(type: 'decode', id: message.id, geometry), buffers
					catch error
						console.error(error)
						parentPort.postMessage(type: 'error', id: message.id, error: error.message)
					finally
						draco.destroy(decoder)
				)

	decodeGeometry = (draco, decoder, array, taskConfig) ->
		attributeIDs = taskConfig.attributeIDs
		attributeTypes = taskConfig.attributeTypes
		dracoGeometry = null
		decodingStatus = null
		geometryType = decoder.GetEncodedGeometryType(array)
		if geometryType is draco.TRIANGULAR_MESH
			dracoGeometry = new draco.Mesh()
			decodingStatus = decoder.DecodeArrayToMesh(array, array.byteLength, dracoGeometry)
		else
			dracoGeometry = new draco.PointCloud()
			decodingStatus = decoder.DecodeArrayToPointCloud(array, array.byteLength, dracoGeometry)
		throw new Error('THREE.DRACOLoader: Decoding failed: #{decodingStatus.error_msg()}') if !decodingStatus.ok() or !dracoGeometry.ptr
		geometry = { index: null, attributes: [] }
		if geometryType is draco.TRIANGULAR_MESH
			geometry.index = decodeIndex(draco, decoder, dracoGeometry)
		for name, id of attributeIDs
			attribute = decodeAttribute(draco, decoder, dracoGeometry, id, draco[name])
			attribute.name = name
			attribute.vertexColorSpace = taskConfig.vertexColorSpace if name is 'color'
			geometry.attributes.push(attribute)
		draco.destroy(dracoGeometry)
		geometry

	decodeIndex = (draco, decoder, dracoGeometry) ->
		numFaces = dracoGeometry.num_faces()
		numIndices = numFaces * 3
		index = new Uint32Array(numIndices)
		indexArray = new draco.DracoInt32Array()
		for i in [0...numFaces]
			decoder.GetFaceFromMesh(dracoGeometry, i, indexArray)
			for j in [0...3]
				index[i * 3 + j] = indexArray.GetValue(j)
		draco.destroy(indexArray)
		{ array: index, itemSize: 1 }

	decodeAttribute = (draco, decoder, dracoGeometry, attributeID, constructor) ->
		numPoints = dracoGeometry.num_points()
		attribute = decoder.GetAttributeByUniqueId(dracoGeometry, attributeID)
		attributeType = constructor.name
		array = switch attributeType
			when 'Int8Array' then new Int8Array(numPoints * attribute.num_components())
			when 'Uint8Array' then new Uint8Array(numPoints * attribute.num_components())
			when 'Int16Array' then new Int16Array(numPoints * attribute.num_components())
			when 'Uint16Array' then new Uint16Array(numPoints * attribute.num_components())
			when 'Int32Array' then new Int32Array(numPoints * attribute.num_components())
			when 'Uint32Array' then new Uint32Array(numPoints * attribute.num_components())
			when 'Float32Array' then new Float32Array(numPoints * attribute.num_components())
		attributeData = new draco.DracoFloat32Array()
		decoder.GetAttributeFloatForAllPoints(dracoGeometry, attribute, attributeData)
		for i in [0...attributeData.size()]
			array[i] = attributeData.GetValue(i)
		draco.destroy(attributeData)
		{ array, itemSize: attribute.num_components() }

module.exports = { default: DRACOLoader }