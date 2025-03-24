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
		self.parser.add_argument("-r", "--replicaNumber", required=True, type=int)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.generateConfig()
		self.saveConfig()

	cdef dict setNode(self, i32 storageUnitId, i32 layer, i32* port, object parent):
		cdef list storageUnits = []
		for i in range(self.option.replicaNumber):
			storageUnits.append({
				"host": "localhost",
				"port": port[0] + i,
				"isMaster": 1 if i == 0 else 0
			})
		cdef dict node = {
			"storageUnitId": storageUnitId,
			"layer": layer,
			"storageUnit": storageUnits,
			"parent": parent
		}
		port[0] += self.option.replicaNumber
		return node

	cdef generateConfig(self):
		cdef list primeNumbersList = [int(x) for x in self.option.primeNumbers.split(',')]
		self.config = {"nodeList": []}
		cdef i32 port = 7410
		cdef i32 storageUnitId = 0
		cdef i32 layer, startParent = 0

		for i in range(primeNumbersList[0]):
			node = self.setNode(storageUnitId, 0, &port, None)
			self.config["nodeList"].append(node)
			storageUnitId += 1

		if len(primeNumbersList) > 1:
			for layer in range(1, len(primeNumbersList)):
				for parent in range(startParent, len(self.config["nodeList"])):
					for i in range(primeNumbersList[layer]):
						node = self.setNode(storageUnitId, layer, &port, parent)
						self.config["nodeList"].append(node)
						storageUnitId += 1

	cdef saveConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "StoreTestConfig.json")
		cdef object fd
		with open(configPath, "w") as fd:
			json.dump(self.config, fd, indent=4)