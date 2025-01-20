from xtore.common.ClientHandler cimport ClientHandler

from argparse import RawTextHelpFormatter
import os, sys, argparse, json

cdef str __help__ = """
"""

def run():
	cdef MasterStoreCLI service = MasterStoreCLI()
	service.run(sys.argv[1:])

cdef class MasterStoreCLI :
	cdef dict config
	cdef object parser
	cdef object option
	cdef ClientHandler handler

	def __init__(self):
		pass

	cdef run(self, list argv) :
		self.getParser(argv)
		self.getConfig()
		self.handler = ClientHandler(self.config["node"][0])
		self.handler.send()

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.option = self.parser.parse_args(argv)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()