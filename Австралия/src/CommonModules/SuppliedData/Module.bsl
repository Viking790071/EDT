#Region Public

// Initiate notification about all available supplied data in Service manager (except those that 
// have the Notification prohibition mark).
//
Procedure RequestAllData() Export
	
	MessageExchange.SendMessage("SuppliedData\QueryAllData", Undefined, 
		SaaS.ServiceManagerEndpoint());
		
EndProcedure

// Get data descriptors by the specified conditions.
//
// Parameters:
//  DataKind - String - name of supplied data kind.
//  Filter - Array - the items should contain the following fields: Code (string) and Value (string).
//
// Returns:
//    XDTODataObject - ArrayOfDescriptor type.
//
Function SuppliedDataDescriptorsFromManager(Val DataKind, Val Filter = Undefined) Export  
	Var Proxy, Conditions, FilterType;
	Proxy = NewProxyOnServiceManager();
	
	If Filter <> Undefined Then
			
		FilterType = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfProperty");
		ConditionType = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Property");
		Conditions = Proxy.XDTOFactory.Create(FilterType);
		For each FilterString In Filter Do
			Condition = Conditions.Property.Add(Proxy.XDTOFactory.Create(ConditionType));
			Condition.Code = FilterString.Code;
			Condition.Value = FilterString.Value;
		EndDo;
	EndIf;
	
	// Convert to standard type.
	Result = Proxy.GetData(DataKind, Conditions);
	Record = New XMLWriter;
	Record.SetString();
	Proxy.XDTOFactory.WriteXML(Record, Result, , , , XMLTypeAssignment.Explicit);
	SerializedResult = Record.Close();
	
	Read = New XMLReader;
	Read.SetString(SerializedResult);
	Result = XDTOFactory.ReadXML(Read);
	Read.Close();
	Return Result;

EndFunction

// Initiates data processing.
//
// May be used in conjunction with SuppliedDataDescriptorsFromManager for manual initiation of the 
// data processing. After method call the system will act as if it has only received a notice about 
// the availability of new data with the specified descriptor NewDataAvailable will be called then, 
// if necessary,
// ProcessNewData for relevant handlers.
//
// Parameters:
//   Descriptor - XDTODataObject - Descriptor.
//
Procedure ImportAndProcessData(Val Descriptor) Export
	
	SuppliedDataMessagesMessageHandler.HandleNewDescriptor(Descriptor);
	
EndProcedure
	
// Moves the data into the SuppliedData catalog .
//
// The data is saved either to a volume on a hard disk or to the SuppliedData table field, depending 
// on the StoreFilesInVolumesOnHardDisk constant and availability of volumes. Data can be later 
// retrieved by search by attributes or by specifying a unique ID, which one was passed to the 
// Descriptor.FileGUID field. If the base already has data with the same data kind and set of key 
// characteristics new data replaces the old one.
//  In this case update of the existing catalog item is used rather than deletion and creating a new 
// one.
//
// Parameters:
//   Descriptor - XDTODataObject - Descriptor or structure with fields.
//	 	"DataKind, AddedAt, FileID, Characteristics", where Characteristics are array of structures 
//    	with the following fields "Code, Value, Key".
//   PathToFile - String – extracted file full name.
//
Procedure SaveSuppliedDataInCache(Val Descriptor, Val PathToFile) Export
	
	// Handle the descriptor to the accepted kind.
	If TypeOf(Descriptor) = Type("Structure") Then
		InEnglish = New Structure;
		InEnglish.Insert("DataType", Descriptor.DataKind);
		InEnglish.Insert("CreationDate", Descriptor.AddedOn);
		InEnglish.Insert("FileGUID", Descriptor.FileID);
		InEnglish.Insert("Properties", New Structure("Property", New Array));
		
		If TypeOf(Descriptor.Characteristics) = Type("Array") Then
			For each Characteristic In Descriptor.Characteristics Do
				InEnglish.Properties.Property.Add(New Structure("Code, Value, IsKey",
				Characteristic.Code, Characteristic.Value, Characteristic.KeyStructure));
			EndDo; 
		EndIf;
		Descriptor = InEnglish;			
	EndIf;
	
	Filter = New Array;
	For each Characteristic In Descriptor.Properties.Property Do
		If Characteristic.IsKey Then
			Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
		EndIf;
	EndDo;
	
	SourceAreaData = Undefined;
	If SaaS.DataSeparationEnabled() AND SaaS.SeparatedDataUsageAvailable() Then
		SourceAreaData = SaaS.SessionSeparatorValue();
		SaaS.SetSessionSeparation(False);
	EndIf;
	
	BeginTransaction();
	Try
	
		Query = QueryDataByNames(Descriptor.DataType, Filter);
		Result = Query.Execute();
		
		Lock = New DataLock;
		LockItem = Lock.Add("Catalog.SuppliedData");
		LockItem.DataSource = Result;
		LockItem.UseFromDataSource("Ref", "SuppliedData");
		Lock.Lock();
		
		Selection = Result.Select();
		
		Data = Undefined;
		PathToOldFile = Undefined;
		
		While Selection.Next() Do
			If Data = Undefined Then
				Data = Selection.SuppliedData.GetObject();
				If Data.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
					PathToOldFile = FilesOperationsInternal.FullVolumePath(Data.Volume) + Data.PathToFile;
				EndIf;
			Else
				DeleteSuppliedDataFromCache(Selection.SuppliedData);
			EndIf;
		EndDo;		
		
		If Data = Undefined Then
			Data = Catalogs.SuppliedData.CreateItem();
		EndIf;
			
		Data.DataKind =  Descriptor.DataType;
		Data.AddedOn = Descriptor.CreationDate;
		Data.FileID = Descriptor.FileGUID;
		Data.DataCharacteristics.Clear();
		For each Property In Descriptor.Properties.Property Do
			Characteristic = Data.DataCharacteristics.Add();
			Characteristic.Characteristic = Property.Code;
			Characteristic.Value = Property.Value;
		EndDo; 
		Data.FileStorageType = FilesOperationsInternal.FilesStorageTyoe();

		If Data.FileStorageType = Enums.FileStorageTypes.InInfobase Then
			Data.StoredFile = New ValueStorage(New BinaryData(PathToFile));
			Data.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			Data.PathToFile = "";
		Else
			// Adding the file to a volume with sufficient free space.
			FileInfo = FilesOperationsInternal.AddFileToVolume(PathToFile, Data.AddedOn, String(Data.FileID), "");
			Data.StoredFile = Undefined;
			Data.Volume = FileInfo.Volume;
			Data.PathToFile = FileInfo.PathToFile;
		EndIf;
		
		Data.Write();
		If PathToOldFile <> Undefined Then
			
			TemporaryFile = New File(PathToOldFile);
			If TemporaryFile.Exist() Then
				
				Try
					TemporaryFile.SetReadOnly(False);
					DeleteFiles(PathToOldFile);
				Except
					WriteLogEvent(
						NStr("ru = 'Поставляемые данные.Удаление файлов в томе'; en = 'Supplied data.File deletion in volume'; pl = 'Dostarczone dane.Usuwanie plików z woluminu';es_ES = 'Datos suministrados.Eliminación de los archivos en el volumen';es_CO = 'Datos suministrados.Eliminación de los archivos en el volumen';tr = 'Sağlanan veriler. Ciltteki dosyaların silinmesi';it = 'Dati forniti. Eliminazione dei file nel volume';de = 'Gelieferte Daten. Dateien im Volumen löschen'",
						     CommonClientServer.DefaultLanguageCode()),
						EventLogLevel.Error,
						,
						,
						ErrorInfo());
				EndTry;
				
			EndIf;
			
		EndIf;
		
		If SourceAreaData <> Undefined Then
			
			SaaS.SetSessionSeparation(True, SourceAreaData);
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		If SourceAreaData <> Undefined Then
			
			SaaS.SetSessionSeparation(True, SourceAreaData);
			
		EndIf;
		
		Raise;
		
	EndTry;
		
EndProcedure

// Removes file from cache.
//
// Parameters:
//  RefOrID - CatalogRef.SuppliedData - reference to the supplied data,
//                         - UUID - a UUID.
//
Procedure DeleteSuppliedDataFromCache(Val RefOrID) Export
	Var Data, FullPath;
	
	SetPrivilegedMode(True);
	
	If TypeOf(RefOrID) = Type("UUID") Then
		RefOrID = Catalogs.SuppliedData.FindByAttribute("FileID", RefOrID);
		If RefOrID.IsEmpty() Then
			Return;
		EndIf;
	EndIf;
	
	Data = RefOrID.GetObject();
	If Data = Undefined Then 
		Return;
	EndIf;
	
	If Data.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		FullPath = FilesOperationsInternal.FullVolumePath(Data.Volume) + Data.PathToFile;
		DeleteFiles(FullPath);
	EndIf;
	
	Delete = New ObjectDeletion(RefOrID);
	Delete.DataExchange.Load = True;
	Delete.Write();
	
EndProcedure

// Gets a data descriptor from the cache.
//
// Parameters:
//  RefOrID - CatalogRef.SuppliedData - reference to the supplied data,
//                         - UUID - a UUID.
//  AsXDTO - Boolean - in what form to return values.
//
// Returns:
//    XDTODataObject - ArrayOfDescriptor type.
//
Function DescriptorSuppliedDataInCache(Val RefOrID, Val AsXDTO = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	If TypeOf(RefOrID) = Type("UUID") Then
		Suffix = "CatalogSuppliedData.FileID = &FileID";
		Query.SetParameter("FileID", RefOrID);
	Else
		Suffix = "CatalogSuppliedData.Ref = &Ref";
		Query.SetParameter("Ref", RefOrID);
	EndIf;
	
	Query.Text = "SELECT
    |	CatalogSuppliedData.FileID,
    |	CatalogSuppliedData.AddedOn,
    |	CatalogSuppliedData.DataKind,
    |	CatalogSuppliedData.DataCharacteristics.(
    |		Value,
    |		Characteristic)
	|FROM
	|	Catalog.SuppliedData AS CatalogSuppliedData
	|	WHERE " + Suffix;
	 
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		Return ?(AsXDTO, GetXDTODescriptor(Selection), GetDescriptor(Selection));
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns binary data of the attached file.
//
// Parameters:
//  RefOrID - CatalogRef.SuppliedData - reference to the supplied data,
//                         - UUID - a UUID.
//
// Returns:
//  BinaryData - binary data of supplied data.
//
Function SuppliedDataFromCache(Val RefOrID) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(RefOrID) = Type("UUID") Then
		RefOrID = Catalogs.SuppliedData.FindByAttribute("FileID", RefOrID);
		If RefOrID.IsEmpty() Then
			Return Undefined;
		EndIf;
	EndIf;
	
	FileObject = RefOrID.GetObject();
	If FileObject = Undefined Then
		Return Undefined;
	EndIf;
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		Return FileObject.StoredFile.Get();
	Else
		FullPath = FilesOperationsInternal.FullVolumePath(FileObject.Volume) + FileObject.PathToFile;
		
		Try
			Return New BinaryData(FullPath)
		Except
			// Record to the event log.
			ErrorMessage = ErrorTextWhenYouReceiveFile(ErrorInfo(), RefOrID);
			WriteLogEvent(
				NStr("ru = 'SuppliedData.Получение файла из тома'; en = 'SuppliedData.Receive the file from the volume'; pl = 'SuppliedData.Obieranie pliku z woluminu';es_ES = 'Datos proporcionados.Recibiendo el archivo del volumen';es_CO = 'Datos proporcionados.Recibiendo el archivo del volumen';tr = 'Sağlanan veri. Dosyanın birimden alınması';it = 'Dati forniti. Acquisizione del file dal volume';de = 'Gelieferte Daten. Datei vom Volumen empfangen'", 
				CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.SuppliedData,
				RefOrID,
				ErrorMessage);
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка открытия файла: файл не найден на сервере.
				           |Обратитесь к администратору.
				           |
				           |Файл: ""%1.%2"".'; 
				           |en = 'An error occurred when opening the file: file is not found on the server.
				           |Contact the administrator.
				           |
				           |File: ""%1.%2"".'; 
				           |pl = 'Wystąpił błąd podczas otwierania pliku: plik nie został znaleziony na serwerze.
				           |Skontaktuj się z administratorem.
				           |
				           |Plik: ""%1.%2"".';
				           |es_ES = 'Ha ocurrido un error al abrir el archivo: el archivo no se ha encontrado en el servidor.
				           |Contactar su administrador.
				           |
				           |Archivo: ""%1.%2"".';
				           |es_CO = 'Ha ocurrido un error al abrir el archivo: el archivo no se ha encontrado en el servidor.
				           |Contactar su administrador.
				           |
				           |Archivo: ""%1.%2"".';
				           |tr = 'Dosya açılırken bir hata oluştu: dosya sunucuda bulunamadı. 
				           |Yöneticinize başvurun. 
				           |
				           |Dosya: ""%1.%2"".';
				           |it = 'Si è verificato un errore all''apertura del file: il file non è stato trovato sul server.
				           |Contattare l''amministratore.
				           |
				           |File: ""%1.%2"".';
				           |de = 'Beim Öffnen ist ein Fehler aufgetreten.
				           |Kontaktieren Sie Ihren Administrator.
				           |
				           |Datei: ""%1.%2"".'"),
				FileObject.Description,
				FileObject.Extension);
		EndTry;
	EndIf;
	
EndFunction

// Checks whether there is data with the specified key characteristics in the cache.
//
// Parameters:
//   Descriptor - XDTODataObject - Descriptor.
//
// Returns:
//  Boolean - the presence of descriptor in the cache.
//
Function IsInCache(Val Descriptor) Export
	
	Filter = New Array;
	For each Characteristic In Descriptor.Properties.Property Do
		If Characteristic.IsKey Then
			Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
		EndIf;
	EndDo;
	
	Query = QueryDataByNames(Descriptor.DataType, Filter);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns the array of references for the data that meets the specified conditions.
//
// Parameters:
//  DataKind - String - name of supplied data kind.
//  Filter - Array - the items should contain the following fields: Code (string) and Value (string).
//
// Returns:
//    Array - array of data references.
//
Function SuppliedDataReferencesFromCache(Val DataKind, Val Filter = Undefined) Export
	
	Query = QueryDataByNames(DataKind, Filter);
	Return Query.Execute().Unload().UnloadColumn("SuppliedData");
	
EndFunction

// Get data by the specified conditions.
//
// Parameters:
//  DataKind - String - name of supplied data kind.
//  Filter - Array - the items should contain the following fields: Code (string) and Value (string).
//  AsXDTO - Boolean - in what form to return values.
//
// Returns:
//    XDTODataObject - ArrayOfDescriptor type or
//    Array of structures with the following fields "DataKind, AddedAt, FileID, Characteristics", 
//    where Characteristics are array of structures with the following fields "Code, Value, Key".
//	  To get the file, call GetSuppliedDataFromCache.
//
//
Function SuppliedDataFromCacheDescriptors(Val DataKind, Val Filter = Undefined, Val AsXDTO = False) Export
	Var Query, QueryResult, Selection, Descriptors, Result;
	
	Query = QueryDataByNames(DataKind, Filter);
		
	Query.Text = "SELECT
    |	CatalogSuppliedData.FileID,
    |	CatalogSuppliedData.AddedOn,
    |	CatalogSuppliedData.DataKind,
    |	CatalogSuppliedData.DataCharacteristics.(
    |		Value,
    |		Characteristic)
	|FROM
	|	Catalog.SuppliedData AS CatalogSuppliedData
	|	WHERE CatalogSuppliedData.Ref IN (" + Query.Text + ")";
	 
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If AsXDTO Then
		Result = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfDescriptor"));
		Descriptors = Result.Descriptor;
	Else
		Result = New Array();
		Descriptors = Result;
	EndIf;

	While Selection.Next()  Do
		Message = ?(AsXDTO, GetXDTODescriptor(Selection), GetDescriptor(Selection));
		Descriptors.Add(Message);
	EndDo;		
	
	Return Result;
	
EndFunction	

// Returns a custom supplied data descriptor presentation.
// Can be used to output messages to the event log.
//
// Parameters:
//  Descriptor - XDTODataObject - Descriptor type or structure with fields.
//	 	"DataKind, AddedAt, FileID, Characteristics", where Characteristics are array of structures 
//    	with the following fields "Code, Value".
//
// Returns:
//  String - custom descriptor presentation.
//
Function GetDataDescription(Val Descriptor) Export
	Var Details, Characteristic;
	
	If Descriptor = Undefined Then
		Return "";
	EndIf;
	
	If TypeOf(Descriptor) = Type("XDTODataObject") Then
		Details = Descriptor.DataType;
		For each Characteristic In Descriptor.Properties.Property Do
			Details = Details
				+ ", " + Characteristic.Code + ": " + Characteristic.Value;
		EndDo; 
		
		If Descriptor.RecommendedUpdateDate = Undefined Then
			
			Descriptor.RecommendedUpdateDate = CurrentUniversalDate();
			
		EndIf;
		
		Details = Details + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = ', добавлен: %1 (%2), рекомендовано загрузить: %3 (%2)'; en = ', added: %1 (%2), recommended to import: %3 (%2)'; pl = ', dodano: %1 (%2), zaleca się zaimportować: %3 (%2)';es_ES = ', añadido: %1 (%2), se recomienda importar: %3 (%2)';es_CO = ', añadido: %1 (%2), se recomienda importar: %3 (%2)';tr = ', eklendi: %1(%2), içe aktarılması önerilir: %3(%2)';it = ', aggiunto: %1 (%2), si consiglia di importare: %3 (%2)';de = ', hinzugefügt: %1 (%2), es wird empfohlen zu importieren: %3 (%2)'"), 
			ToLocalTime(Descriptor.CreationDate, SessionTimeZone()),
			TimeZonePresentation(SessionTimeZone()), 
			ToLocalTime(Descriptor.RecommendedUpdateDate));
	Else
		Details = Descriptor.DataKind;
		For each Characteristic In Descriptor.Characteristics Do
			Details = Details
				+ ", " + Characteristic.Code + ": " + Characteristic.Value;
		EndDo; 
		
		Details = Details + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = ', добавлен: %1 (%2)'; en = ', added: %1 (%2)'; pl = ', dodany: %1 (%2)';es_ES = ', añadido: %1 (%2)';es_CO = ', añadido: %1 (%2)';tr = ', eklendi: %1 (%2)';it = ', aggiunto:%1 (%2)';de = ', hinzugefügt: %1 (%2)'"), 
			ToLocalTime(Descriptor.AddedOn, SessionTimeZone()),
			TimeZonePresentation(SessionTimeZone()));
	EndIf;
		
	Return Details;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////////
// Update information in data areas.

// Returns the list of data areas where the supplied data have not been copied yet.
//
// In case of the first call of the function the full set of available areas returned.
// In case of subsequent call, when recovering from a failure, only the raw area will be returned.
//  After copying data to an area, call AreaProcessed.
//
// Parameters:
//  FileID - UUID - supplied data file ID,
//  HandlerCode - String - handler code,
//  IncludingShared - Boolean - if True, the area with code -1 will be added to all available areas.
// 
// Returns:
//  Array - areas that require processing.
//
Function AreasRequireProcessing(Val FileID, Val HandlerCode, Val IncludingShared = False) Export
	
	RecordSet = InformationRegisters.AreasRequireSuppliedDataProcessing.CreateRecordSet();
	RecordSet.Filter.FileID.Set(FileID);
	RecordSet.Filter.HandlerCode.Set(HandlerCode);
	RecordSet.Read();
	If RecordSet.Count() = 0 Then
		Query = New Query;
		Query.Text = "SELECT
		               |	&FileID AS FileID,
		               |	&HandlerCode AS HandlerCode,
		               |	DataAreas.DataAreaAuxiliaryData AS DataArea
		               |FROM
		               |	InformationRegister.DataAreas AS DataAreas
		               |WHERE
		               |	DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)";
		Query.SetParameter("FileID", FileID);
		Query.SetParameter("HandlerCode", HandlerCode);
		RecordSet.Load(Query.Execute().Unload());
		
		If IncludingShared Then
			CommonCourses = RecordSet.Add();
			CommonCourses.FileID = FileID;
			CommonCourses.HandlerCode = HandlerCode;
			CommonCourses.DataArea = -1;
		EndIf;
		
		RecordSet.Write();
	EndIf;
	Return RecordSet.UnloadColumn("DataArea");
EndFunction	

// Removes the area from the list of unprocessed ones. Disables the session separation (if it was 
// enabled) because with enabled separation writing in the notseparated register is prohibited.
//
// Parameters:
//  FileID - UUID - supplied data file,
//  HandlerCode - String - handler code,
//  DataArea - Namber - the ID of the processed area.
// 
Procedure AreaProcessed(Val FileID, Val HandlerCode, Val DataArea) Export
	
	If SaaS.DataSeparationEnabled() AND SaaS.SeparatedDataUsageAvailable() Then
		SaaS.SetSessionSeparation(False);
	EndIf;
	
	RecordSet = InformationRegisters.AreasRequireSuppliedDataProcessing.CreateRecordSet();
	RecordSet.Filter.FileID.Set(FileID);
	If DataArea <> Undefined Then
		RecordSet.Filter.DataArea.Set(DataArea);
	EndIf;
	RecordSet.Filter.HandlerCode.Set(HandlerCode);
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See JobQueueOverridable.OnDefineHandlerAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("SuppliedDataMessagesMessageHandler.ImportData");
	
EndProcedure

// See MessageExchangeOverridable.GetMessageChannelHandlers. 
Procedure MessageChannelHandlersOnDefine(Handlers) Export
	
	SuppliedDataMessagesMessageHandler.GetMessageChannelHandlers(Handlers);
	
EndProcedure

#EndRegion

#Region Private

Function NewProxyOnServiceManager()
	
	URL = SaaS.InternalServiceManagerURL();
	Username = SaaS.AuxiliaryServiceManagerUsername();
	UserPassword = SaaS.AuxiliaryServiceManagerUserPassword();

	ServiceAddress = URL + "/ws/SuppliedData?wsdl";
	
	ConnectionParameters = Common.WSProxyConnectionParameters();
	ConnectionParameters.WSDLAddress = ServiceAddress;
	ConnectionParameters.NamespaceURI = "http://www.1c.ru/SaaS/1.0/WS";
	ConnectionParameters.ServiceName = "SuppliedData";
	ConnectionParameters.UserName = Username; 
	ConnectionParameters.Password = UserPassword;
	
	Return Common.CreateWSProxy(ConnectionParameters);
	
EndFunction

// Get the query that returns references to the data with the specified characteristics.
//
// Parameters:
//  DataKind - string.
//  Characteristics - the collection that contains the Code(string) structure.
//                   And the Value(string).
//
// Returns:
//   Query
Function QueryDataByNames(Val DataKind, Val Characteristics)
	If Characteristics = Undefined Or Characteristics.Count() = 0 Then
		Return QueryByDataKind(DataKind);
	Else
		Return QueryByCharacteristicNames(DataKind, Characteristics);
	EndIf;
EndFunction

Function QueryByDataKind(Val DataKind)
	Query = New Query();
	Query.Text = "SELECT
	|	SuppliedData.Ref AS SuppliedData
	|FROM
	|	Catalog.SuppliedData AS SuppliedData
	|WHERE
	|	SuppliedData.DataKind = &DataKind";
	Query.SetParameter("DataKind", DataKind);
	Return Query;
	
EndFunction

Function QueryByCharacteristicNames(Val DataKind, Val Characteristics)
// SELECT Reference
// FROM Characteristic
// WHERE (CharacteristicsName = '' AND CharacteristicValue = '') OR ..(N)
// GROUP ON DataId
// HAVING Count(*) = N.
	Query = New Query();
	Query.Text = 
	"SELECT
	|	DataCharacteristicsSuppliedData.Ref AS SuppliedData
	|FROM
	|	Catalog.SuppliedData.DataCharacteristics AS DataCharacteristicsSuppliedData
	|WHERE 
	|	DataCharacteristicsSuppliedData.Ref.DataKind = &DataKind AND (";
	Counter = 0;
	For Each Characteristic In Characteristics Do
		If Counter > 0 Then
			Query.Text = Query.Text + " OR ";
		EndIf; 
		
		Query.Text = Query.Text + "(
		| CAST(DataCharacteristicsSuppliedData.Value AS String(150)) = &Value" + Counter + "
		| AND DataCharacteristicsSuppliedData.Characteristic = &Code" + Counter + ")";
		Query.SetParameter("Value" + Counter, Characteristic.Value);
		Query.SetParameter("Code" + Counter, Characteristic.Code);
		Counter = Counter + 1;
	EndDo;
	Query.Text = Query.Text + ")
	|GROUP BY
	|	DataCharacteristicsSuppliedData.Ref
	|HAVING
	|Count(*) = &Count";
	Query.SetParameter("Count", Counter);
	Query.SetParameter("DataKind", DataKind);
	Return Query;
	
EndFunction

// Transformation of the selection results into an XDTO object.
//
// Parameters:
//  Selection - QueryResultSelection. Query selection that contains information about data updating.
//                 
//
Function GetXDTODescriptor(Selection)
	Descriptor = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Descriptor"));
	Descriptor.DataType = Selection.DataKind;
	Descriptor.CreationDate = Selection.AddedOn;
	Descriptor.FileGUID = Selection.FileID;
	Descriptor.Properties = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfProperty"));
	CharacteristicsSelection = Selection.DataCharacteristics.Select();
	While CharacteristicsSelection.Next() Do
		Characteristic = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Property"));
		Characteristic.Code = CharacteristicsSelection.Characteristic;
		Characteristic.Value = CharacteristicsSelection.Value;
		Characteristic.IsKey = True;
		Descriptor.Properties.Property.Add(Characteristic);
	EndDo; 
	Return Descriptor;
	
EndFunction

Function GetDescriptor(Val Selection)
	Var Descriptor, CharacteristicsSelection, Characteristic;
	
	Descriptor = New Structure("DataKind, AddedOn, FileID, Characteristics");
	Descriptor.DataKind = Selection.DataKind;
	Descriptor.AddedOn = Selection.AddedOn;
	Descriptor.FileID = Selection.FileID;
	Descriptor.Characteristics = New Array();
	
	CharacteristicsSelection = Selection.DataCharacteristics.Select();
	While CharacteristicsSelection.Next() Do
		Characteristic = New Structure("Code, Value, KeyStructure");
		Characteristic.Code = CharacteristicsSelection.Characteristic;
		Characteristic.Value = CharacteristicsSelection.Value;
		Characteristic.KeyStructure = True;
		Descriptor.Characteristics.Add(Characteristic);
	EndDo; 
	
	Return Descriptor;
	
EndFunction

Function CreateObject(Val MessageType)
	
	Return XDTOFactory.Create(MessageType);
	
EndFunction

Function ErrorTextWhenYouReceiveFile(Val ErrorInformation, Val File)
	
	ErrorMessage = BriefErrorDescription(ErrorInformation);
	
	If File <> Undefined Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |
			           |Ссылка на файл: ""%2"".'; 
			           |en = '%1
			           |
			           |Ref to file: ""%2"".'; 
			           |pl = '%1
			           |
			           |Odnośnik do pliku: ""%2"".';
			           |es_ES = '%1
			           |
			           |Referencia al archivo: ""%2"".';
			           |es_CO = '%1
			           |
			           |Referencia al archivo: ""%2"".';
			           |tr = '%1
			           |
			           |Dosya linki: ""%2"".';
			           |it = '%1
			           |
			           |Rif al file: ""%2"".';
			           |de = '%1
			           |
			           |Ref zu Datei: ""%2"".'"),
			ErrorMessage,
			GetURL(File));
	EndIf;
	
	Return ErrorMessage;
	
EndFunction

// Compares if the set of characteristics got from the descriptor meets the filter conditions.
//
// Parameters:
//  Filter - the collection of objects with the Code and Value fields.
//  Characteristics - the collection of objects with the Code and Value fields.
//
// Returns
//   Boolean
//
Function CharacteristicsCoincide(Val Filter, Val Characteristics) Export

	For Each LineOfFilter In Filter Do
		RowFound = False;
		For Each Characteristic In Characteristics Do 
			If Characteristic.Code = LineOfFilter.Code Then
				If Characteristic.Value = LineOfFilter.Value Then
					RowFound = True;
				Else 
					Return False;
				EndIf;
			EndIf;
		EndDo;
		If Not RowFound Then
			Return False;
		EndIf;
	EndDo;
		
	Return True;
	
EndFunction	

#EndRegion
