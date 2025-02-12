from xtore.service.Server cimport Server
from xtore.test.People cimport People
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.BaseType cimport i32, u64

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize
from argparse import RawTextHelpFormatter
import os, sys, argparse, json, traceback, random, time

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cdef NodeStoreCLI service = NodeStoreCLI()
	service.run(sys.argv[1:])

cdef class NodeStoreCLI :
	cdef dict config
	cdef object parser
	cdef object option
	cdef Server service
	cdef Buffer stream

	def __init__(self):
		pass
	
	def __dealloc__(self):
		releaseBuffer(&self.stream)

	cdef run(self, list argv) :
		self.getParser(argv)
		self.getConfig()
		self.service = Server(self.config["node"][0])
		self.service.run(self.handle)

	async def handle(self, reader:object, writer:object) -> None :
		message:bytes = await reader.read(1024)
		cdef i32 length = len(message)
		initBuffer(&self.stream, <char *> malloc(length), length)
		memcpy(self.stream.buffer, <char *> message, length)
		cdef People people = People()
		people.readKey(0, &self.stream)
		self.stream.position += 4
		people.readValue(0, &self.stream)
		print(people)
		writer.write(message)
		await writer.drain()
		writer.close()
		await writer.wait_closed()

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.option = self.parser.parse_args(argv)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()