import re
from xtore.service.Client cimport Client
from xtore.service.Server cimport Server
from xtore.common.Buffer cimport Buffer, getBuffer, initBuffer, releaseBuffer, setBuffer
from xtore.common.Package cimport Package
from xtore.BaseType cimport i32

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize
from argparse import RawTextHelpFormatter
import os, sys, argparse, json

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cdef ClusterCLI service = ClusterCLI()
	service.run(sys.argv[1:])

cdef class ClusterCLI :
	cdef dict config
	cdef dict clusterConfig
	cdef object parser
	cdef object option
	cdef Server server
	cdef Buffer stream
	cdef Buffer sendBack

	def __init__(self):
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		initBuffer(&self.sendBack, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
	
	def __dealloc__(self):
		releaseBuffer(&self.stream)
		releaseBuffer(&self.sendBack)

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-m", "--mode", help="Select load balance algorithm", required=False, type=str)
		self.option = self.parser.parse_args(argv)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			self.clusterConfig = self.config["cluster"] 
			fd.close()

	cdef run(self, list argv) :
		self.getParser(argv)
		self.getConfig()
		self.server = Server(self.config["cluster"])
		self.server.run(self.handleServer)

	cdef bytes pack(self, Package receivedPackage) :
		cdef Package package = Package()
		package.ID = receivedPackage.ID
		package.header = json.dumps(receivedPackage.getHeader())
		package.data = json.dumps(receivedPackage.data)
		print(package)
		package.write(&self.stream)
		return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)

	cdef Package unpack(self, bytes message) :
		cdef i32 length = len(message)
		# memcpy(self.stream.buffer, <char *> message, length)
		setBuffer(&self.stream, <char *> message, length)
		cdef Package package = Package()
		self.stream.position -= length
		package.readKey(&self.stream)
		self.stream.position += 4
		package.readValue(&self.stream)
		return package

	async def handleServer(self, reader:object, writer:object) -> None :
		message:bytes = await reader.read(BUFFER_SIZE)
		cdef Package package = self.unpack(message)
		cdef object header = package.getHeader()
		cdef str mode = self.option.mode if self.option.mode else header["mode"]
		cdef i32 recieveNode
		cdef Client client
		cdef i32 bufferPosition = self.sendBack.position
		if mode == "hash":
			recieveNode = package.ID % len(self.clusterConfig["nodes"])
			client = Client(self.clusterConfig["nodes"][recieveNode])
			await client.connect(self.pack(package), self.handleClient)
		elif mode == "consistent":
			# not implemented yet
			pass
		elif mode == "primering-p":
			# not implemented yet
			pass
		elif mode == "primering-s":
			# not implemented yet
			pass
		else:
			print(f"Mode {mode} not found !")
		writer.write(getBuffer(&self.sendBack, bufferPosition - self.sendBack.position))
		await writer.drain()
		print(f"Send data success !")
		writer.close()
		await writer.wait_closed()

	cdef handleClient(self, bytes recieveData) :
		print(f"Recieve data: {recieveData}")
		print(f"Send data to client...")
		cdef i32 length = len(recieveData)
		setBuffer(&self.sendBack, <char *> recieveData, length)