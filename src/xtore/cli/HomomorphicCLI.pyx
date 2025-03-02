from xtore.BaseType cimport i32
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage
from xtore.instance.ScopeSearch cimport ScopeSearch
from xtore.instance.ScopeSearchResult cimport ScopeSearchResult
from xtore.test.People cimport People

from xtore.instance.HomomorphicBSTStorage import HomomorphicBSTStorage
from xtore.base.CythonHomomorphic cimport CythonHomomorphic
from xtore.test.PeopleHomomorphic cimport PeopleHomomorphic
from xtore.test.EncryptedPeople cimport EncryptedPeople

import os, sys, argparse, traceback, random, time
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from faker import Faker
from argparse import RawTextHelpFormatter

cdef str __help__ = "Test Script for Xtore"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
def run():
    cli = HomomorphicCLI()       
    cli.run(sys.argv[1:])

ctypedef struct TextIntegerArray:
    i32 textLength
    i32 arrayLength
    i32 *array

cdef class HomomorphicCLI:
    cdef object parser
    cdef object option
    cdef object config

    def __init__(self):
        self.config = self.getConfig() 

    def getParser(self, list argv):
        self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
        self.parser.add_argument("test", help="Name of test", choices=[
            'People.HE',
            'Homomorphic',
            'Wrapper',
        ])
        self.parser.add_argument("-n", "--count", help="Number of record to test.", required=False, type=int)
        self.option = self.parser.parse_args(argv)

    cdef run(self, list argv):
        self.getParser(argv)  
        self.checkPath()  
        if self.option.test == 'People.HE': self.testPeopleHomomorphic()
        elif self.option.test == 'Homomorphic': self.testHomomorphic()
        elif self.option.test == 'Wrapper': self.testHomomorphic()

    cdef testHomomorphic(self):
        cdef int slots = 1
        cdef CythonHomomorphic homomorphic = CythonHomomorphic()
        homomorphic.initializeCKKS(17, 50, 60, 8192, 1)  
        homomorphic.setupSchemeSwitching(slots, 25)
        cipherText1 =  homomorphic.encrypt([1])
        cipherText2 =  homomorphic.encrypt([2])
        result = homomorphic.compare(slots, cipherText1, cipherText2)
        print(result)

        decryptedText = homomorphic.decrypt(cipherText1)

    cdef testPeopleHomomorphic(self):
        cdef str resourcePath = self.getResourcePath()
        cdef str path = f'{resourcePath}/People.HE.bin'
        cdef StreamIOHandler io = StreamIOHandler(path)
        cdef PeopleHomomorphic storage = PeopleHomomorphic(io)
        cdef bint isNew = not os.path.isfile(path)
        cdef int n = self.option.count
        io.open()
        try:
            if isNew: storage.create()
            else: storage.readHeader(0)
            # peopleList = self.writePeople(storage)
            # storedList = self.readPeople(storage, peopleList)
            # self.comparePeople(peopleList, storedList)
            # storage.writeHeader()

        except:
            print(traceback.format_exc())
        io.close()

    cdef TextIntegerArray* toI32Array(self, str text):
        cdef bytes encoded = text.encode()
        cdef char *buffer = <char *> encoded
        cdef i32 length = len(encoded)
        cdef i32 arraySize = ((length >> 2) + 1) << 2
        cdef TextIntegerArray *array = <TextIntegerArray *> malloc(sizeof(TextIntegerArray))

        array.textLength = length
        array.arrayLength = (length >> 3) + 1
        array.array = <i32 *> malloc(arraySize)

        cdef i32 position = 0
        for i in range(array.arrayLength - 1):
            memcpy(<void *> (&array.array[i]), <void *> (buffer + position), 4)
            position += 4
        memcpy(array.array + (array.arrayLength - 1), buffer + position, length - position)
        return array

    cdef void freeTextIntegerArray(self, TextIntegerArray* array):
        if array:
            if array.array:
                free(array.array) 
            free(array)

    cdef checkPath(self):
        cdef str resourcePath = self.getResourcePath()
        if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

    cdef str getResourcePath(self):
        if IS_VENV: return f'{sys.prefix}/var/xtore'
        else: return '/var/xtore'

    @staticmethod
    def getConfig():
        return {}