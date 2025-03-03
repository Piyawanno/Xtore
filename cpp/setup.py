#!/usr/bin/env python

from multiprocessing import Process, cpu_count, Queue
from sysconfig import get_paths
import sys, os, time, platform

PROCESS_NUMBER = cpu_count()
IS_WINDOWS = sys.platform in ['win32', 'win64']
IS_VENV = sys.prefix != sys.base_prefix
OPERATION = ['build', 'install', 'link', 'uninstall', 'clean']
HELP = "Builder script for Xtore C++ implementation"

class XtoreBuilder:
	def __init__(self, root):
		print("Root Path: %s"%(root))
		os.chdir(root)
		self.root = root
		self.objectPath = '%s/build/'%(self.root)
		self.isMain = False
		self.main = ''
		self.libraryName = "xtorecpp"
		self.compiler = "g++"
		self.objectFlag = "-Wall -pedantic -ansi -fPIC -DPIC -c -O3 -g --std=c++17"
		self.mergeFlag = "-Wall -pedantic -ansi -fPIC -DPIC -O3 -g --std=c++17 -shared"
		self.shareFlag = "-shared -O3"
		self.include = [
			'./',
			get_paths()['include'],
			os.path.join(sys.prefix, "include"),
		]
		self.libraryPath = [
			'./',
			get_paths()['platlib'],
			os.path.join(sys.prefix, "lib")
		]
		self.objectLibrary = [
		]
		self.library = []
		self.exceptedInstall = []
		self.fileList = []
		self.objectList = []
	
	def operate(self, operation: str):
		self.checkBasePath()
		self.checkExistingLib()
		if operation == 'build':
			if '--merge' in sys.argv: self.buildMerged()
			else: self.build()
		elif operation == 'clean':
			self.clean()
		elif operation == 'install':
			self.install()
		elif operation == 'link':
			self.link()
		elif operation == 'uninstall':
			self.uninstall()
			
	def checkBasePath(self):
		self.userPath = sys.prefix if IS_VENV else "/usr"

	def checkExistingLib(self) :
		openfhePath:str = os.path.join(sys.prefix, "include", "openfhe")
		if os.path.isdir(openfhePath) :
			self.include.extend([
				openfhePath,
				os.path.join(sys.prefix, "include", "openfhe", "binfhe"),
				os.path.join(sys.prefix, "include", "openfhe", "cereal"),
				os.path.join(sys.prefix, "include", "openfhe", "core"),
				os.path.join(sys.prefix, "include", "openfhe", "pke"),
			])
			self.library.extend([
				"OPENFHEcore",
				"OPENFHEpke",
				"OPENFHEbinfhe",
			])
	
	def getTargetName(self):
		if not self.isMain :
			if platform.system() == 'Linux' : return 'lib%s.so'%(self.libraryName)
			elif platform.system() == 'Darwin' : return 'lib%s.dylib'%(self.libraryName)
			else: return '%s.dll'%(self.libraryName)
		else:
			return self.main[:self.main.find('.')]
	
	def install(self):
		if self.isMain: command = 'cp -v %s/%s %s/bin/'%(self.root, self.main[:-4], self.userPath)
		else: command = 'cp -v %s/%s %s/lib/'%(self.root, self.getTargetName(), self.userPath)
		print(command)
		os.system(command)
		excepted = ['%s/%s'%(self.root, i) for i in self.exceptedInstall]
		for root, dirs, files in os.walk(self.root):
			targetDir = root.replace(self.root, "%s/include/%s"%(self.userPath, self.libraryName))
			for i in files:
				if (i[-4:] == '.hpp' or i[-2] == '.h') and root not in excepted:
					target = f'{targetDir}/{i}'
					path = f'{root}/{i}'
					if not os.path.isdir(targetDir):
						os.makedirs(targetDir)
					if not os.path.isfile(target) or os.path.getmtime(path) > os.path.getmtime(target):
						command = 'cp %s/%s %s'%(root, i, targetDir)
						print(command)
						os.system(command)

	def link(self):
		if self.isMain:
			source = f'{self.root}/{self.main[:-4]}'
			destination = f'{self.userPath}/bin/{self.main[:-4]}'
		else:
			source = f'{self.root}/{self.getTargetName()}'
			destination = f'{self.userPath}/lib/{self.getTargetName()}'
		if not os.path.isfile(destination):
			command = f'ln -s {source} {destination}'
			print(command)
			os.system(command)
		excepted = ['%s/%s'%(self.root, i) for i in self.exceptedInstall]
		for root, dirs, files in os.walk(self.root):
			targetDir = root.replace(self.root, "%s/include/%s"%(self.userPath, self.libraryName))
			for i in files:
				if (i[-4:] == '.hpp' or i[-2] == '.h') and root not in excepted:
					target = f'{targetDir}/{i}'
					path = f'{root}/{i}'
					if not os.path.isdir(targetDir):
						os.makedirs(targetDir)
					if not os.path.isfile(target):
						command = 'ln -s %s/%s %s/%s'%(root, i, targetDir, i)
						print(command)
						os.system(command)
	
	def uninstall(self):
		if self.isMain: command = 'rm -v %s/%s %s/bin/%s'%(self.root, self.main[:-4], self.userPath, self.main[:-4])
		else: command = 'rm -v %s/%s %s/lib/%s'%(self.root, self.getTargetName(), self.userPath, self.getTargetName())
		print(command)
		os.system(command)
		targetDir = "%s/include/%s"%(self.userPath, self.libraryName)
		command = "rm -rfv %s"%(targetDir)
		print(command)
		os.system(command)
	
	def clean(self):
		os.system('rm -rfv %s/build'%(self.root))
		os.system('rm -v %s/%s'%(self.root, self.getTargetName()))
	
	def build(self):	
		start = time.time()
		self.getTargetTime()
		self.createBuildPath()
		self.browse()
		self.buildObject()
		self.buildLibrary()
		if self.isMain: self.buildMain()
		print("Finish building in %.3fs"%(time.time() - start))
	
	def buildMerged(self):
		library = ' '.join(['-l%s'%(i) for i in self.library])
		includePath = ' '.join(['-I%s'%(i) for i in self.include])
		libraryPath = ' '.join(['-L%s'%(i) for i in self.libraryPath])
		source = []
		for root, dirs, files in os.walk(self.root):
			for i in files:
				if i[-4:] == '.cpp': source.append("%s/%s"%(root, i))
		command = '{compiler} {option} {includePath} {libraryPath} -o {output} {source} {library}'.format(
			compiler=self.compiler,
			option=self.mergeFlag,
			includePath=includePath,
			libraryPath=libraryPath,
			output=self.getTargetName(),
			source=' '.join(source),
			library=library
		)
		print(command)
		os.system(command)
	
	def getTargetTime(self):
		target = self.getTargetName()
		path = "%s/%s"%(self.root, target)
		if not os.path.isfile(path): self.targetTime = 0
		else: self.targetTime = os.stat(path)[-2]
	
	def createBuildPath(self):
		path = self.root+'/build'
		if not os.path.isdir(path): os.mkdir(path)
	
	def browse(self):
		for root, dirs, files in os.walk(self.root):
			for i in files:
				if (i[-4:] == '.cpp' or i[-2:] == '.c') and (not self.isMain or i != self.main):
					self.fileList.append((root, i))
					buildPath = "%s/build%s"%(self.root, root.replace(self.root, ''))
					if not os.path.isdir(buildPath):
						os.system("mkdir -p %s"%(buildPath))
	
	def runObjectBuildCommand(self, queue):
		while True:
			commandList = queue.get()
			if len(commandList) == 0:
				queue.put([])
				break
			command, path, fileName, formatted = commandList.pop(0)
			queue.put(commandList)
			print(formatted)
			if os.system(command) != 0:
				raise RuntimeError("File %s/%s cannot be compiled."%(path, fileName))

	def parallelBuildObject(self, commandList):
		processList = []
		queue = Queue()
		queue.put(commandList)
		for i in range(PROCESS_NUMBER):
			process = Process(target=self.runObjectBuildCommand, args=(queue, ))
			process.start()
			processList.append(process)
		for process in processList:
			process.join()

	def buildObject(self):
		self.hasNewObject = False
		include = " ".join(["-I%s"%(i) for i in self.include])
		libraryPath = ' '.join(["-L%s"%(i) for i in self.libraryPath])
		library = " ".join(["-l%s"%(i) for i in self.objectLibrary])
		self.isBuildLibrary = False
		i = 1
		filtered = []
		for path, fileName in self.fileList:
			buildPath = "%s/build%s"%(self.root, path.replace(self.root, ''))
			name = fileName[:fileName.find('.')]
			objectPath = "%s/%s.o"%(buildPath, name)
			if self.isNew("%s/%s"%(path, fileName)) or not os.path.isfile(objectPath):
				filtered.append((path, fileName, buildPath, name, objectPath))
			self.objectList.append(objectPath)
		n = len(filtered)
		commandList = []
		for path, fileName, buildPath, name, objectPath in filtered:
			self.isBuildLibrary = True
			if not os.path.isdir(buildPath): os.mkdir(buildPath)
			command = "%s %s %s %s %s -o %s/%s.o %s/%s"%(
				self.compiler,
				self.objectFlag,
				include,
				libraryPath,
				library,
				buildPath,
				name,
				path,
				fileName
			)
			formatted = "\033[93m[%d|%d]\033[0m %s"%(i, n, command)
			commandList.append((command, path, fileName, formatted))
			i += 1
			self.hasNewObject = True
		self.parallelBuildObject(commandList)
	
	def buildLibrary(self):
		if self.isBuildLibrary and self.hasNewObject:
			include = ' '.join(["-I%s"%(i) for i in self.include])
			libraryPath = ' '.join(["-L%s"%(i) for i in self.libraryPath])
			library = ' '.join(["-l%s"%(i) for i in self.library])
			objectList = " ".join(self.objectList)
			command = "%s %s %s %s %s %s -o %s"%(
				self.compiler,
				include,
				libraryPath,
				objectList,
				self.shareFlag,
				library,
				self.getTargetName()
			)
			print(command.replace(self.objectPath, ''))
			if os.system(command) != 0:
				raise RuntimeError("Shared library %s cannot be compiled."%(self.getTargetName()))
	
	def buildMain(self):
		if self.isBuildLibrary:
			include = ' '.join(["-I%s"%(i) for i in self.include])
			libraryPath = ' '.join(["-L%s"%(i) for i in self.libraryPath])
			library = ' '.join(["-l%s"%(i) for i in self.library])
			command = "%s %s %s %s -o %s"%(
				self.compiler,
				include,
				libraryPath,
				self.main,
				library,
				self.getTargetName(),
			)
			print(command)
			if os.system(command) != 0:
				raise RuntimeError("Main program %s cannot be compiled."%(self.main))

	def isNew(self, path):
		return os.stat(path)[-2] > self.targetTime
	
if __name__ == '__main__':
	from argparse import RawTextHelpFormatter
	import argparse
	parser = argparse.ArgumentParser(description=HELP, formatter_class=RawTextHelpFormatter)
	parser.add_argument(
		"operation",
		help="Operation of setup",
		choices=OPERATION,
	)
	option = parser.parse_args(sys.argv[1:])
	builder = XtoreBuilder(os.path.abspath(os.path.dirname(__file__)+'/src'))
	builder.operate(option.operation)
