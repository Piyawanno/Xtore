from xtore.common.ServerHandler cimport ServerHandler

from argparse import RawTextHelpFormatter
import os, sys, argparse, json

cdef str __help__ = """
"""

def run():
	cdef NodeStoreCLI service = NodeStoreCLI()
	service.run(sys.argv[1:])

cdef class NodeStoreCLI :
	cdef dict config
	cdef object parser
	cdef object option
	cdef ServerHandler handler

	def __init__(self):
		pass

	cdef run(self, list argv) :
		self.getParser(argv)
		self.getConfig()
		self.handler = ServerHandler(self.config["node"][0])
		self.handler.run()

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.option = self.parser.parse_args(argv)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()