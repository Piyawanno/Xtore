from argparse import RawTextHelpFormatter, ArgumentParser

import os, subprocess, sys

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix

def run():
	cdef SpawnServerCLI cli = SpawnServerCLI()
	cli.run(sys.argv[1:])

cdef class SpawnServerCLI :
	cdef object parser
	cdef object option

	cdef getParser(self, list argv) :
		self.parser = ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-u", "--host", help="Target Server host.", required=False, type=str, default='127.0.0.1')
		self.parser.add_argument("-p", "--port", help="Initial Port.", required=False, type=int, default=7001)	
		self.parser.add_argument("-n", "--number", help="Amount of Server.", required=False, type=int, default=6)
		self.parser.add_argument("-m", "--mode", help="Cluster Mode.", required=False, choices=['spawn', 'kill', 'drop'], default='spawn')
		self.option = self.parser.parse_args(argv)

	cdef spawnServers(self):
		print('Create Server...')

		cdef str basePath = "venvs"
		cdef str venvPath
		cdef str sessionName

		for port in range(self.option.port, self.option.port + self.option.number):
			venvPath = os.path.join(basePath, f"db{port}.venv")
			sessionName = f"db{port}-server"

			subprocess.run(["tmux", "new-session", "-d", "-s", sessionName])

			createVenvCommands = [
				f"python -m venv {venvPath}",
				f"source {venvPath}/bin/activate && pip install --upgrade pip && pip install -r requirements.txt",
				f"tmux wait-for -S done-{port}"
			]

			runServerCommands = [
				f"source {venvPath}/bin/activate",
				"python XtoreSetup.py link",
				"chmod +x ./script/*",
				f"xt-server -p {port}",
			]

			if not os.path.exists(venvPath):
				for cmd in createVenvCommands:
					subprocess.run(["tmux", "send-keys", "-t", sessionName, cmd, "C-m"])

			for cmd in runServerCommands:
				subprocess.run(["tmux", "send-keys", "-t", sessionName, cmd, "C-m"])

			print(f"🚀 Server-{port} is being created...")
			

		for port in range(self.option.port, self.option.port + self.option.number):
			if not os.path.exists(venvPath):
				subprocess.run(["tmux", "wait-for", f"done-{port}"])

		# subprocess.run(["xt-create-config", "-p", "2,3,5", "-r", "1"])
		subprocess.run(["sleep", "20"])
		print("✅ All servers have finished setup!")

	cdef killServers(self):
		print('Kill Server...')

		cdef str sessionName
		for port in range(self.option.port, self.option.port + self.option.number):
			sessionName = f"db{port}-server"
			subprocess.run(["tmux", "kill-session", "-t", sessionName])
			print(f"🔥 Server-{port} is being killed...")

		print("✅ All servers have been killed!")

	cdef dropDB(self):
		print('Drop DB...')

		for port in range(self.option.port, self.option.port + self.option.number):
			venvPath = os.path.join("venvs", f"db{port}.venv")
			# delete file var/xtore/People.BST.bin in venv
			if os.path.exists(venvPath):
				subprocess.run(["rm", "-rf", os.path.join(venvPath, "var", "xtore", "People.BST.bin")])
				print(f"🔥 DB-{port} is being drop...")
		print("✅ All db have been remove!")

	cdef run(self, list argv) :
		self.getParser(argv)
		if self.option.mode == 'spawn': self.spawnServers()
		elif self.option.mode == 'kill': self.killServers()
		elif self.option.mode == 'drop': self.dropDB()
		else: print("Invalid mode")
