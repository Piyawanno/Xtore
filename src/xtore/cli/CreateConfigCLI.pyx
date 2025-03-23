#!/usr/bin/env python3
from xtore.BaseType cimport i32
from argparse import RawTextHelpFormatter
import os, sys, argparse, json

cdef str __help__ = "Script to generate node config"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cli = CreateConfigCLI()
	cli.run(sys.argv[1:])

cdef class CreateConfigCLI:
	cdef object parser
	cdef object option
	cdef dict config

	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-p", "--primeNumbers", required=True, type=str)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.generateConfig()
		self.saveConfig()

	cdef generateConfig(self):
		cdef list primeNumbersList = [int(x) for x in self.option.primeNumbers.split(',')]
		self.config = {"nodeList": []}
		cdef i32 setPort = 7410
		cdef i32 storageUnitId = 0
		cdef i32 layer, startParent = 0

		#Layer0
		for i in range(primeNumbersList[0]):
			node = {
				"storageUnitId": storageUnitId,
				"layer": 0,
				"storageUnit": [
					{"host": "localhost", "port": setPort, "isMaster": 1},
					{"host": "localhost", "port": setPort + 1, "isMaster": 0},
					{"host": "localhost", "port": setPort + 2, "isMaster": 0}
				],
				"parent": None
			}
			self.config["nodeList"].append(node)
			setPort += 3
			storageUnitId += 1

		if len(primeNumbersList) > 1:
			for layer in range(1, len(primeNumbersList)):
				for parent in range(startParent, len(self.config["nodeList"])):
					for i in range(primeNumbersList[layer]):
						node = {
							"storageUnitId": storageUnitId,
							"layer": layer,
							"storageUnit": [
								{"host": "localhost", "port": setPort, "isMaster": 1},
								{"host": "localhost", "port": setPort + 1, "isMaster": 0},
								{"host": "localhost", "port": setPort + 2, "isMaster": 0}
							],
							"parent": parent
						}
						self.config["nodeList"].append(node)
						setPort += 3
						storageUnitId += 1

	cdef saveConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "TestCreateConfig.json")
		cdef object fd
		with open(configPath, "w") as fd:
			json.dump(self.config, fd, indent=4)