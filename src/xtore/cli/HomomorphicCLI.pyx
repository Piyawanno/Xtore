from xtore.BaseType cimport i32, f32, bytes
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.Homomorphic cimport Homomorphic
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage
from xtore.instance.ScopeSearch cimport ScopeSearch
from xtore.instance.ScopeSearchResult cimport ScopeSearchResult
from xtore.instance.HomomorphicBSTStorage import HomomorphicBSTStorage
from xtore.test.PeopleHomomorphic cimport PeopleHomomorphic
from xtore.test.People cimport People
from xtore.test.EncryptedPeople cimport EncryptedPeople

import os, sys, argparse, traceback, random, time
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from faker import Faker
from argparse import RawTextHelpFormatter

from openfhe import (
        Serialize, 
        BINARY, 
        DeserializeCiphertextString,
    )

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
            'Homomorphic'
        ])
        self.parser.add_argument("-n", "--count", help="Number of record to test.", required=False, type=int)
        self.option = self.parser.parse_args(argv)

    cdef run(self, list argv):
        self.getParser(argv)  
        self.checkPath()  
        if self.option.test == 'People.HE': self.testPeopleHomomorphic()
        elif self.option.test == 'Homomorphic': self.testHomomorphic()

    cdef testHomomorphic(self):
        cdef Homomorphic homomorphic = Homomorphic()
        # homomorphic.createCKKS(17, 50, 60, 8192, 1)         
        homomorphic.createCKKS(10, 25, 30, 4096, 1)         
        homomorphic.createFHEW(25, 1)
        cdef object ciphertext1 = homomorphic.encrypt(10) 
        cdef object ciphertext2 = homomorphic.encrypt(20)
        cdef object difference = homomorphic.diff(ciphertext1, ciphertext2)
        cdef object sign = homomorphic.getSign(difference)

        cdef object serializeText1 = Serialize(ciphertext1, BINARY)
        cdef object serializeText2 = Serialize(ciphertext2, BINARY)

        cdef object deserailizeText1 = DeserializeCiphertextString(serializeText1, BINARY)
        cdef object deserailizeText2 = DeserializeCiphertextString(serializeText2, BINARY)
        cdef object diffDeserializeText = homomorphic.diff(deserailizeText1, deserailizeText2)
        cdef object signDeserializeText = homomorphic.getSign(diffDeserializeText)

        print("diff 1.Ciphertext, 2.DeserailizeText : ",sign, signDeserializeText)

        cdef f32 decryptedText = homomorphic.decrypt(deserailizeText1)

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
            peopleList = self.writePeople(storage)
            storedList = self.readPeople(storage, peopleList)
            self.comparePeople(peopleList, storedList)
            # storage.writeHeader()

        except:
            print(traceback.format_exc())
        io.close()

    cdef list writePeople(self, BasicStorage storage):
        cdef EncryptedPeople people
        cdef Homomorphic homomorphic = Homomorphic()
        cdef TextIntegerArray* i32array
        cdef i32 i32name
        cdef i32 i32lastname
        cdef int i
        cdef int n = self.option.count
        cdef list peopleList = []
        cdef double start = time.time()
        cdef object fake = Faker()
        cdef object encryptedID
        cdef object encryptedName
        cdef object encryptedSurname
        cdef object encryptedIncome

        # homomorphic.createCKKS(17, 50, 60, 8192, 1)  
        homomorphic.createCKKS(10, 25, 30, 4096, 1)       
        homomorphic.createFHEW(25, 1)

        for i in range(n):
            people = EncryptedPeople()
            people.position = -1

        # Generate and get people's data
            i32array = self.toI32Array(fake.first_name())
            i32name = i32array.array[0]
            self.freeTextIntegerArray(i32array)

            i32array = self.toI32Array(fake.last_name())
            i32lastname = i32array.array[0]
            self.freeTextIntegerArray(i32array)

        # Encrypt data
            #encID = homomorphic.encrypt(random.randint(1_000_000_000_000, 9_999_999_999_999))
            encryptedName = homomorphic.encrypt(i32name) 
            encryptedSurname = homomorphic.encrypt(i32lastname)
            encryptedIncome = homomorphic.encrypt(random.uniform(1_000, 9_999))
            print("encName :",type(encryptedName))

        # Serialize
            #people.ID = serialID
            people.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
            people.income = Serialize(encryptedIncome, BINARY)
            people.name = Serialize(encryptedName, BINARY)

            people.surname = Serialize(encryptedSurname, BINARY)
            peopleList.append(people)

        # Deserialize
            # id_ser = Serialize(encID, BINARY)
            # name_ser = Serialize(encName, BINARY)
            # surname_ser = Serialize(encSurname, BINARY)
            # income_ser = Serialize(encIncome, BINARY)

            # deserialize_name = DeserializeCiphertextString(serialize_name, BINARY)
            # deserialize_lastname = DeserializeCiphertextString(serialize_lastname, BINARY)

            # print("Encrypted datatype : ",type(encryptedName))
            # print("Serialize datatype : ",type(serialize_name))
            # print("Deserialize datatype: ", type(deserialize_name))
        
        cdef double elapsed = time.time() - start
        print(f'>>> People Data of {n} are generated in {elapsed:.3}s')
        start = time.time()
        for people in peopleList:
            storage.set(people)
        elapsed = time.time() - start
        print(f'>>> People Data of {n} are stored in {elapsed:.3}s ({(n/elapsed)} r/s)')
        return peopleList
    
    cdef list readPeople(self, BasicStorage storage, list peopleList):
        cdef list storedList = []
        cdef EncryptedPeople stored
        cdef double start = time.time()
        for people in peopleList:
            stored = storage.get(people, None)
            storedList.append(stored)
        cdef double elapsed = time.time() - start
        cdef int n = len(peopleList)
        print(f'>>> People Data of {n} are read in {elapsed:.3}s ({(n/elapsed)} r/s)')
        return storedList
    
    cdef comparePeople(self, list referenceList, list comparingList):
        cdef EncryptedPeople reference, comparing
        cdef double start = time.time()
        cdef object id_des
        cdef object ref_name_dser
        cdef object ref_surname_dser
        cdef object ref_income_dser
        cdef object comp_name_dser
        cdef object comp_surname_dser
        cdef object comp_income_dser
        cdef object nmDiff, surDiff, incDiff
        cdef object nmSign, surSign, incSign

        cdef Homomorphic homomorphic = Homomorphic()
        # homomorphic.createCKKS(17, 50, 60, 8192, 1)  
        homomorphic.createCKKS(10, 25, 30, 4096, 1)       
        homomorphic.createFHEW(25, 1)

        for reference, comparing in zip(referenceList, comparingList):        

            try:
                assert(reference.ID == comparing.ID)
                # assert(incSign == 0)
                # assert(nmSign == 0)
                # assert(surSign == 0)
            except Exception as error:
                print(reference, comparing)
                raise error
        cdef double elapsed = time.time() - start
        cdef int n = len(referenceList)
        print(f'>>> People Data of {n} are checked in {elapsed:.3}s')
    
    cdef iteratePeople(self, BasicStorage storage):
        cdef BasicIterator iterator
        cdef EncryptedPeople entry = EncryptedPeople()
        cdef EncryptedPeople comparing
        cdef int n = 0
        cdef double start = time.time()
        cdef double elapsed
        iterator = storage.createIterator()
        iterator.start()
        while iterator.getNext(entry):
            n += 1
        elapsed = time.time() - start
        print(f'>>> People Data of {n} are iterated in {elapsed:.3}s ({(n/elapsed)} r/s)')
    
    cdef searchPeople(self, ScopeTreeStorage storage, list[EncryptedPeople] peopleList):
        cdef EncryptedPeople reference = EncryptedPeople()
        reference.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
        cdef ScopeSearch search = ScopeSearch(storage)
        cdef ScopeSearchResult result = search.getGreater(reference)
        cdef EncryptedPeople people = EncryptedPeople()
        while result.getNext(people):
            assert people.ID > reference.ID
        
        result = search.getLess(reference)
        while result.getNext(people):
            assert people.ID < reference.ID

        reference = random.choice(peopleList)
        result = search.getGreaterEqual(reference)
        while result.getNext(people):
            assert people.ID >= reference.ID
        
        result = search.getLessEqual(reference)
        while result.getNext(people):
            assert people.ID <= reference.ID
        
        cdef EncryptedPeople other = random.choice(peopleList)
        cdef EncryptedPeople start = reference if reference.ID < other.ID else other
        cdef EncryptedPeople end = reference if reference.ID >= other.ID else other
        result = search.getRange(start, end, False, False)
        while result.getNext(people):
            assert people.ID > start.ID and people.ID < end.ID

        result = search.getRange(start, end, True, False)
        while result.getNext(people):
            assert people.ID >= start.ID and people.ID < end.ID

        result = search.getRange(start, end, False, True)
        while result.getNext(people):
            assert people.ID > start.ID and people.ID <= end.ID

        result = search.getRange(start, end, True, True)
        while result.getNext(people):
            assert people.ID >= start.ID and people.ID <= end.ID


    cdef TextIntegerArray* toI32Array(self, str text):
        cdef bytes encoded = text.encode()
        cdef char *buffer = <char *> encoded
        cdef i32 length = len(encoded)
        cdef i32 arraySize = ((length >> 2) + 1) << 2
        #cdef TextIntegerArray *array = <TextIntegerArray *> malloc(sizeof(TextIntegerArray) + arraySize)
        cdef TextIntegerArray *array = <TextIntegerArray *> malloc(sizeof(TextIntegerArray))

        array.textLength = length
        array.arrayLength = (length >> 3) + 1
        #array.array = <i32 *> (array + 8)
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