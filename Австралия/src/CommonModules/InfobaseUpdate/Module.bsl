#Region Public

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for use in update handlers.
//

// Records changes into the passed object.
// To be used in update handlers.
//
// Parameters:
//   Data - Arbitrary - an object, record set, or manager of the constant to be written.
//                                                      
//   RegisterOnExchangePlanNodes - Boolean - enables registration in exchange plan nodes when writing the object.
//   EnableBusinessLogic - Boolean - enables business logic when writing the object.
//
Procedure WriteData(Val Data, Val RegisterOnExchangePlanNodes = Undefined, 
	Val EnableBusinessLogic = False) Export
	
	Data.DataExchange.Load = Not EnableBusinessLogic;
	Data.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", RegisterOnExchangePlanNodes);
	
	If RegisterOnExchangePlanNodes = Undefined
		Or Not RegisterOnExchangePlanNodes Then
		Data.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	Data.Write();
	
	MarkProcessingCompletion(Data);
	
EndProcedure

// Records changes in a passed reference object.
// To be used in update handlers.
//
// Parameters:
//   Object - Arbitrary - the reference object to be written. For example, CatalogObject.
//   RegisterOnExchangePlanNodes - Boolean - enables registration in exchange plan nodes when writing the object.
//   EnableBusinessLogic - Boolean - enables business logic when writing the object.
//   DocumentWriteMode - DocumentWriteMode - valid only for DocumentObject data type - the document 
//                                                            write mode.
//											If the parameter is not passed, the document is written in the Write mode.
//
Procedure WriteObject(Val Object, Val RegisterOnExchangePlanNodes = Undefined, 
	Val EnableBusinessLogic = False, WriteMode = Undefined) Export
	
	Object.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", RegisterOnExchangePlanNodes);
	Object.DataExchange.Load = Not EnableBusinessLogic;
	
	If RegisterOnExchangePlanNodes = Undefined
		Or Not RegisterOnExchangePlanNodes
		AND Not Object.IsNew() Then
		Object.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	If WriteMode <> Undefined Then
		If TypeOf(WriteMode) <> Type("DocumentWriteMode") Then
			ExceptionText = NStr("ru = 'Неправильный тип параметра DocumentWriteMode'; en = 'Invalid type of DocumentWriteMode parameter.'; pl = 'Niepoprawny typ DocumentWriteMode parametru.';es_ES = 'Tipo incorrecto del parámetro DocumentWriteMode.';es_CO = 'Tipo incorrecto del parámetro DocumentWriteMode.';tr = 'DocumentWriteMode parametresinin türü yanlıştır';it = 'Tipo di parametro documento Modalità di registrazione non corretto.';de = 'Falscher Typ des Parameters Dokumentenaufzeichnungsmodus'");
			Raise ExceptionText;
		EndIf;
		Object.DataExchange.Load = Object.DataExchange.Load
			AND Not WriteMode = DocumentWriteMode.Posting
			AND Not WriteMode = DocumentWriteMode.UndoPosting;
		Object.Write(WriteMode);
	Else
		Object.Write();
	EndIf;
	
	MarkProcessingCompletion(Object);
	
EndProcedure

// Records changes in the passed data set.
// To be used in update handlers.
//
// Parameters:
//   RecordSet                      - InformationRegisterRecordSet,
//                                       AccumulationRegisterRecordSet,
//                                       AccountingRegisterRecordSet,
//                                       CalculationRegisterRecordSet - the record set to be written.
//   Replace - Boolean - defines the record replacement mode in accordance with the current filter 
//       criteria. True - the existing records are deleted before writing. False - the new records 
//       are appended to the existing records.
//   RegisterOnExchangePlanNodes - Boolean - enables registration in exchange plan nodes when writing the object.
//   EnableBusinessLogic - Boolean - enables business logic when writing the object.
//
Procedure WriteRecordSet(Val RecordSet, Replace = True, Val RegisterOnExchangePlanNodes = Undefined,
	Val EnableBusinessLogic = False) Export
	
	RecordSet.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", RegisterOnExchangePlanNodes);
	RecordSet.DataExchange.Load = Not EnableBusinessLogic;
	
	If RegisterOnExchangePlanNodes = Undefined 
		Or Not RegisterOnExchangePlanNodes Then
		RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		RecordSet.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	RecordSet.Write(Replace);
	
	MarkProcessingCompletion(RecordSet);
	
EndProcedure

// Deletes the passed object.
// To be used in update handlers.
//
// Parameters:
//  Data - Arbitrary - the object to be deleted.
//  RegisterOnExchangePlanNodes - Boolean - enables registration in exchange plan nodes when writing the object.
//  EnableBusinessLogic - Boolean - enables business logic when writing the object.
//
Procedure DeleteData(Val Data, Val RegisterOnExchangePlanNodes = Undefined, 
	Val EnableBusinessLogic = False) Export
	
	Data.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", RegisterOnExchangePlanNodes);
	
	Data.DataExchange.Load = Not EnableBusinessLogic;
	If RegisterOnExchangePlanNodes = Undefined 
		Or Not RegisterOnExchangePlanNodes Then
		Data.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	Data.Delete();
	
EndProcedure

// Returns a string constant for generating event log messages.
//
// Returns:
//   String - the text of an event in the event log.
//
Function EventLogEvent() Export
	
	Return InfobaseUpdateInternal.EventLogEvent();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to check object availability when running deferred update.
//

// If there are unfinished deferred update handlers that process the passed Data object, the 
// procedure throws an exception or locks form to disable editing.
// 
//
// For calls made from the deferred update handler (handler interface check scenario), the check 
// does not start unless the DeferredHandlerName parameter is specified. The blank parameter means 
// the update order is formed during the update queue generation.
//
// Parameters:
//  Data - AnyRef, RecordSet, Object, FormDataStructure, String - the object reference, the object 
//           itself, record set or full name of the metadata object whose handler is to be checked.
//  Form - ClientApplicationForm - if an object is not processed, the ReadOnly property is set for the passed 
//           form. If the form is not passed, an exception is thrown.
//           
//
//  DeferredHandlerName - String - unless blank, checks that another deferred handler that makes a 
//           call has a smaller queue number than the current deferred number.
//           If the queue number is greater, it throws an exception as it is forbidden to use 
//           application interface specified in the InterfaceProcedureName parameter.
//
//  InterfaceProcedureName - String - the application interface name displayed in the exception 
//           message shown when checking queue number of the deferred handler specified in the 
//           DeferredHandlerName parameter.
//
//  Example:
//   Locking object form in the OnCreateAtServer module handler.
//   InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
//
//   Locking object (a record set) form in the BeforeWrite module handler:
//   InfobaseUpdate.CheckObjectProcessed(ThisObject);
//
//   Check that the object is updated and throw the DigitalSignature.UpdateSignature procedure 
//   exception unless the object is not processed by
//   Catalog.DigitalSignatures.ProcessDataForMigrationToNewVersion
//
//   InfobaseUpdate.CheckObjectProcessed(SignedObject,,
//      "Catalog.DigitalSignatures.ProcessDataForMigrationToNewVersion",
//      "DigitalSignature.UpdateSignature");
//
//   Check that all objects of the type are updated:
//   AllOrdersProcessed = InfobaseUpdate.CheckObjectProcessed("Document.CustomerOrder");
//
Procedure CheckObjectProcessed(Data, Form = Undefined, DeferredHandlerName = "", InterfaceProcedureName = "") Export
	
	If Not IsCallFromUpdateHandler() Then
		Result = ObjectProcessed(Data);
		If Result.Processed Then
			Return;
		EndIf;
			
		If Form = Undefined Then
			Raise Result.ExceptionText;
		EndIf;
		
		Form.ReadOnly = True;
		CommonClientServer.MessageToUser(Result.ExceptionText);
		Return;
	EndIf;
	
	If Not ValueIsFilled(DeferredHandlerName) Then
		Return;
	EndIf;
	
	If DeferredHandlerName = SessionParameters.UpdateHandlerParameters.HandlerName Then
		Return;
	EndIf;
	
	RequiredHandlerQueue = DeferredUpdateHandlerQueue(DeferredHandlerName);
	CurrentHandlerQueue = SessionParameters.UpdateHandlerParameters.DeferredProcessingQueue;
	If CurrentHandlerQueue > RequiredHandlerQueue Then
		Return;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Недопустимо вызывать %1
		           |из обработчика обновления
		           |%2
		           |так как его номер очереди меньше или равен номеру очереди обработчика обновления
		           |%3'; 
		           |en = 'Cannot call %1
		           |from update handler
		           |%2
		           | as its queue number is less than or equal to the queue number of update handler
		           |%3.'; 
		           |pl = 'Nie dopuszczalne jest wezwanie %1
		           |z programu przetwarzania aktualizacji
		           |%2
		           |ponieważ jego numer kolejki jest mniejszy lub równy numeru kolejki programu przetwarzania aktualizacji
		           |%3';
		           |es_ES = 'No se admite llamar %1
		           |del procesador de actualización 
		           |%2
		           |porque su número de orden es menos o igual al número de orden del procesador de actualización
		           |%3';
		           |es_CO = 'No se admite llamar %1
		           |del procesador de actualización 
		           |%2
		           |porque su número de orden es menos o igual al número de orden del procesador de actualización
		           |%3';
		           |tr = 'Güncelleştirme işleyicisinden çağırmak%1
		           | için geçerli değil, çünkü sıra numarası
		           |%2
		           | güncelleştirme işleyicisinin sıra numarasına eşit veya daha küçük
		           |%3';
		           |it = 'Non devono causare %1
		           |dal gestore aggiornamenti 
		           |%2
		           |così come il numero di coda è inferiore o uguale coda gestore aggiornamenti
		           |%3.';
		           |de = 'Rufen Sie %1
		           |nicht vom
		           |%2
		           |Update-Handler auf, da seine Warteschlangennummer kleiner oder gleich der Warteschlangennummer des Update-Handlers ist
		           |%3'"),
		InterfaceProcedureName,
		SessionParameters.UpdateHandlerParameters.HandlerName,
		DeferredHandlerName);
	
EndProcedure

// Check whether there are deferred update handlers that are processing the passed Data object.
// 
//
// Parameters:
//  Data - AnyRef, RecordSet, Object, FormDataStructure, String - the object reference, the object 
//           itself, record set, or full name of the metadata object whose lock is to be checked.
//
// Returns:
//   Structure - with the following fields:
//     * Processed - Boolean - the flag showing whether the object is processed.
//     * ExceptionText - String - the exception text in case the object is not processed. Contains 
//                         the list of unfinished handlers.
//
// Example:
//   Check that all objects of the type are updated:
//   AllOrdersProcessed = InfobaseUpdate.ObjectProcessed("Document.CustomerOrder");
//
Function ObjectProcessed(Data) Export
	
	Result = New Structure;
	Result.Insert("Processed", True);
	Result.Insert("ExceptionText", "");
	Result.Insert("IncompleteHandlersString", "");
	
	If Data = Undefined Then
		Return Result;
	EndIf;
	
	If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		
		IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
		If Not IsSubordinateDIBNode Then
			Return Result;
		ElsIf GetFunctionalOption("DeferredMasterNodeUpdateCompleted") Then
			Return Result;
		EndIf;
		
	EndIf;
	
	LockedObjectsInfo = InfobaseUpdateInternal.LockedObjectsInfo();
	
	If TypeOf(Data) = Type("String") Then
		FullName = Data;
	Else
		MetadataAndFilter = MetadataAndFilterByData(Data);
		FullName = MetadataAndFilter.Metadata.FullName();
	EndIf;
	
	ObjectToCheck = StrReplace(FullName, ".", "");
	
	ObjectHandlers = LockedObjectsInfo.ObjectsToLock[ObjectToCheck];
	If ObjectHandlers = Undefined Then
		Return Result;
	EndIf;
	
	Processed = True;
	IncompleteHandlers = New Array;
	For Each Handler In ObjectHandlers Do
		HandlerProperties = LockedObjectsInfo.Handlers[Handler];
		If HandlerProperties.Completed Then
			Processed = True;
		ElsIf TypeOf(Data) = Type("String") Then
			Processed = False;
		Else
			Processed = Common.CalculateInSafeMode(
				HandlerProperties.CheckProcedure + "(Parameters)", MetadataAndFilter);
		EndIf;
		
		Result.Processed = Processed AND Result.Processed;
		
		If Not Processed Then
			IncompleteHandlers.Add(Handler);
		EndIf;
	EndDo;
	
	If IncompleteHandlers.Count() > 0 Then
		ExceptionText = NStr("ru = 'Действия с объектом временно запрещены, так как не завершен переход на новую версию программы.
			|Это плановый процесс, который скоро завершится.
			|Остались следующие процедуры обработки данных:'; 
			|en = 'Operations with this object are temporarily blocked
			|until the scheduled upgrade to a new version is completed.
			|The following data processing procedures are not yet completed:'; 
			|pl = 'Czynności z obiektem tymczasowo są zabronione, ponieważ nie jest zakończone przejście do nowej wersji programu.
			|To jest proces planowy, który niedługo będzie zakończony.
			|Zostały następujące procedury przetwarzania danych:';
			|es_ES = 'Las acciones con el objeto están temporalmente prohibidas porque no se ha terminado el traspaso a la nueva versión del programa.
			|Es un proceso planificado que terminará dentro de poco.
			|Quedan los siguientes procedimientos de procesamiento de datos:';
			|es_CO = 'Las acciones con el objeto están temporalmente prohibidas porque no se ha terminado el traspaso a la nueva versión del programa.
			|Es un proceso planificado que terminará dentro de poco.
			|Quedan los siguientes procedimientos de procesamiento de datos:';
			|tr = 'Programın yeni bir sürümüne geçiş tamamlanmadığı için nesne eylemleri geçici olarak yasaktır. 
			|Yakında sona erecek planlı bir süreçtir. 
			|Aşağıdaki veri işleme işlemleri kalmıştır:';
			|it = 'Le azioni con un oggetto sono temporaneamente vietate perché non è stato completato il passaggio alla nuova versione del programma.
			|Questo è un processo pianificato che finirà presto.
			|Sono rimaste le seguenti procedure di elaborazione dei dati:';
			|de = 'Aktionen mit dem Objekt sind vorübergehend verboten, da die Migration auf die neue Version des Programms nicht abgeschlossen ist.
			|Dies ist ein geplanter Prozess, der in Kürze abgeschlossen sein wird.
			|Die folgenden Verfahren der Datenverarbeitung bleiben bestehen:'");
		
		IncompleteHandlersString = "";
		For Each IncompleteHandler In IncompleteHandlers Do
			IncompleteHandlersString = IncompleteHandlersString + Chars.LF + IncompleteHandler;
		EndDo;
		Result.ExceptionText = ExceptionText + IncompleteHandlersString;
		Result.IncompleteHandlersString = IncompleteHandlersString;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for deferred update handlers with Parallel execution mode.
// 
//

// Checking that the passed data is updated.
//
// Parameters:
//  Data - Reference, Array, DataSet - the data the changes to be recorded for.
//							 - ValueTable - independent information register dimension values. Requirements:
//													- All register dimensions are included in the main filter.
//													- The table contains only the columns that match the register dimension names
//														the handler has been assigned to.
//													- During the update, the sets are recorded with the same filter
//														the handler has been assigned with.
//													- AdditionalParameters obtains the flag value and the full register name.
//  AdditionalParameters - Structure - see InfobaseUpdate.AdditionalProcessingMarkParameters. 
//  PositionInQueue - Number, Undefined - the position in a processing queue where the current handler is running. 
//													By default, you do not have to pass the position as its value is obtained from the parameters of the session that runs the update handler.
//
Procedure MarkProcessingCompletion(Data, AdditionalParameters = Undefined, PositionInQueue = Undefined) Export
	If PositionInQueue = Undefined Then
		If SessionParameters.UpdateHandlerParameters.ExecutionMode <> "Deferred"
			Or SessionParameters.UpdateHandlerParameters.DeferredHandlerExecutionMode <> "Parallel" Then
			Return;
		EndIf;
		PositionInQueue = SessionParameters.UpdateHandlerParameters.DeferredProcessingQueue;
	EndIf;
	
	If Not SessionParameters.UpdateHandlerParameters.HasProcessedObjects Then
		NewSessionParameters = InfobaseUpdateInternal.NewUpdateHandlerParameters();
		
		FillPropertyValues(NewSessionParameters, SessionParameters.UpdateHandlerParameters);
		NewSessionParameters.HasProcessedObjects = True;
		
		SessionParameters.UpdateHandlerParameters = New FixedStructure(NewSessionParameters);
	EndIf;
	
	DataCopy = Data;
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingMarkParameters();
	EndIf;
	
	If (TypeOf(Data) = Type("Array")
		Or TypeOf(Data) = Type("ValueTable"))
		AND Data.Count() = 0 Then
		
		ExceptionText = NStr("ru = 'В процедуру InfobaseUpdate.MarkProcessingCompletion передан пустой массив. Не возможно отметить выполнение обработки.'; en = 'An empty array is passed to InfobaseUpdate.MarkProcessingCompletion procedure. Cannot mark the data processing procedure as completed.'; pl = 'Do procedury InfobaseUpdate.MarkProcessingCompletion został przekazany pusty masyw. Niemożliwe jest zaznaczenie wykonania przetwarzania.';es_ES = 'En el procedimiento InfobaseUpdate.MarkProcessingCompletion se ha pasado una matriz vacía. No se puede marcar la ejecución del procesamiento.';es_CO = 'En el procedimiento InfobaseUpdate.MarkProcessingCompletion se ha pasado una matriz vacía. No se puede marcar la ejecución del procesamiento.';tr = 'InfobaseUpdate.MarkProcessingCompletion prosedürüne boş küme aktarıldı. İşlem yürütülemedi.';it = 'Nella procedura di aggiornamento della base di informazioni.Contrassegna L''esecuzione Dell''elaborazione è passata a una matrice vuota. Non è possibile contrassegnare l''esecuzione dell''elaborazione.';de = 'Zur Prozedur der InfobaseUpdate.MarkProcessingCompletion wird ein leeres Array übertragen. Es ist nicht möglich, die Verarbeitungsausführung zu markieren.'");
		Raise ExceptionText;
		
	EndIf;
	
	Node = QueueRef(PositionInQueue);
	
	If AdditionalParameters.IsRegisterRecords Then
		
		Set = Common.ObjectManagerByFullName(AdditionalParameters.FullRegisterName).CreateRecordSet();
		
		If TypeOf(Data) = Type("Array") Then
			For Each ArrayRow In Data Do
				Set.Filter.Recorder.Set(ArrayRow);
				ExchangePlans.DeleteChangeRecords(Node, Set);
			EndDo;
		Else
			Set.Filter.Recorder.Set(Data);
			ExchangePlans.DeleteChangeRecords(Node, Set);
		EndIf;
		
	ElsIf AdditionalParameters.IsIndependentInformationRegister Then
		
		Set = Common.ObjectManagerByFullName(AdditionalParameters.FullRegisterName).CreateRecordSet();
		ObjectMetadata = Metadata.FindByFullName(AdditionalParameters.FullRegisterName);
		
		SetMissingFiltersInSet(Set, ObjectMetadata, Data);	
		
		For each TableRow In Data Do
			For Each Column In Data.Columns Do
				Set.Filter[Column.Name].Value = TableRow[Column.Name];
				Set.Filter[Column.Name].Use = True;
			EndDo;
			
			ExchangePlans.DeleteChangeRecords(Node, Set);
		EndDo;
		
	Else
		If TypeOf(Data) = Type("MetadataObject") Then
			ExceptionText = NStr("ru = 'Не поддерживается отметка выполнения обработки обновления целиком объекта метаданных. Нужно отмечать обработку конкретных данных.'; en = 'Setting ""update processing completed"" flag to an entire metadata object is not supported. This flag can be set to specific data.'; pl = 'Nie jest obsługiwane zaznaczenie pola wyboru"" zakończone przetwarzanie aktualizacji"" dla całego obiektu metadanych. Trzeba zaznaczać przetwarzanie konkretnych danych.';es_ES = 'No se admite la marca de ejecución del procesamiento de actualización del objeto de metadatos entero. Hay que marcar el procesamiento de datos en concreto.';es_CO = 'No se admite la marca de ejecución del procesamiento de actualización del objeto de metadatos entero. Hay que marcar el procesamiento de datos en concreto.';tr = 'Meta veri nesnesinin tamamını güncelleştirme işleme yürütme işareti desteklenmiyor. Belirli verilerin işlenmesi işaretlenmelidir.';it = 'Non è supportata la quota altimetrica per l''elaborazione dell''aggiornamento dell''intero oggetto metadati. È necessario contrassegnare l''elaborazione di dati specifici.';de = 'Es wird nicht unterstützt, das gesamte Metadatenobjekt als aktualisiert zu markieren. Es ist notwendig, die Verarbeitung bestimmter Daten zu kennzeichnen.'");
			Raise ExceptionText;
		EndIf;
		
		If TypeOf(Data) <> Type("Array") Then
			
			ObjectValueType = TypeOf(Data);
			ObjectMetadata  = Metadata.FindByType(ObjectValueType);
			
			If Common.IsInformationRegister(ObjectMetadata)
				AND ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
				Set = Common.ObjectManagerByFullName(ObjectMetadata.FullName()).CreateRecordSet();
				For Each FilterItem In Data.Filter Do
					Set.Filter[FilterItem.Name].Value = FilterItem.Value;
					Set.Filter[FilterItem.Name].Use = FilterItem.Use;
				EndDo;
				SetMissingFiltersInSet(Set, ObjectMetadata, Data.Filter);
			ElsIf Common.IsRefTypeObject(ObjectMetadata)
				AND Not Common.IsReference(ObjectValueType)
				AND Data.IsNew() Then
				
				Return;
			Else
				Set = Data;
			EndIf;
			
			ExchangePlans.DeleteChangeRecords(Node, Set);
			DataCopy = Set;
		Else
			For Each ArrayElement In Data Do
				ExchangePlans.DeleteChangeRecords(Node, ArrayElement);
			EndDo;
		EndIf;
		
	EndIf;
	
	If Not Common.IsSubordinateDIBNode() Then
		InformationRegisters.DataProcessedInMasterDIBNode.MarkProcessingCompletion(PositionInQueue, DataCopy, AdditionalParameters); 
	EndIf;
	
EndProcedure

// Additional parameters of functions MarkForProcessing and MarkProcessingCompletion.
// 
// Returns:
//  Structure - structure with the following properties:
//     * IsRegisterRecords - Boolean - the Data function parameter passed references to recorders that require update.
//                              The default value is False.
//      * RegisterFullName - String - the full name of the register that requires update. For example, AccumulationRegister.Stock
//      * SelectAllRecorders - Boolean - all posted documents passed in the type second parameter 
//                                           are selected for processing.
//                                           In this scenario, the Data parameter can pass the following
//                                           MetadataObject: Document or DocumentRef.
//      * IsIndependentInformationRegister -  Boolean - the function Data parameter passes table 
//                                                 with dimension values to Update. The default value is False.
//
Function AdditionalProcessingMarkParameters() Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IsRegisterRecords", False);
	AdditionalParameters.Insert("SelectAllRecorders", False);
	AdditionalParameters.Insert("IsIndependentInformationRegister", False);
	AdditionalParameters.Insert("FullRegisterName", "");
	
	Return AdditionalParameters;
	
EndFunction

// The InfobaseUpdate.MarkForProcessing procedure main parameters that are initialized by the change 
// registration mechanism and must not be overridden in the code of procedures that mark update 
// handlers for processing.
//
// Returns:
//  Structure - with the following properties:
//     * PositionInQueue - Number - the position in the queue for the current handler.
//     * WriteChangesForSubordinateDIBNodeWithFilters - FastInfosetWriter - the parameter is 
//          available only when the DataExchange subsystem is embedded.
//
Function MainProcessingMarkParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("PositionInQueue", 0);
	Parameters.Insert("ReRegistration", False);
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		Parameters.Insert("NameOfChangedFile", Undefined);
		Parameters.Insert("WriteChangesForSubordinateDIBNodeWithFilters", Undefined);
		
	EndIf;
	
	Return Parameters; 
	
EndFunction

// Returns normalized information on the passed data.
// Which then is used in data lock check procedures for deferred update handlers.
//
// Parameters:
//  Data - AnyRef, RecordSet, Object, FormDataStructure - the data to be analyzed.
//  AdditionalParameters - Structure, Undefined - see InfobaseUpdate. AdditionalProcessingMarkParameters.
// 
// Returns:
//  Structure - with the following properties:
//      * Data - AnyRef, RecordSet, Object, FormDataStructure - the value of the input Data parameter.
//  	* ObjectMetadata - MetadataObject - the metadata object that matches the Data parameter.
//  	* FullName - String - the metadata object full name (see method MetadataObject.FullName).
//		* Filter - AnyRef - if Data is a reference object, it is the reference value. If Data is a 
//                                            recorder subordinate register, it is the recorder filter value.
//			   	              - Structure - if Data is an independent information register, it is the 
//                                            structure that matches the filters set for the dimensions.
//		* IsNew - Boolean - if Data is a reference object, it is a new object flag.
//                                            For other data types, it is always False.
//	
Function MetadataAndFilterByData(Data, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingMarkParameters();
	EndIf;
	
	If AdditionalParameters.IsRegisterRecords Then
		ObjectMetadata = Metadata.FindByFullName(AdditionalParameters.FullRegisterName);		
	Else
		ObjectMetadata = Undefined;
	EndIf;
	
	Filter = Undefined;
	DataType = TypeOf(Data);
	IsNew = False;
	
	If TypeOf(Data) = Type("String") Then
		ObjectMetadata = Metadata.FindByFullName(Data);
	ElsIf DataType = Type("FormDataStructure") Then
		
		If CommonClientServer.HasAttributeOrObjectProperty(Data, "Ref") Then
			
			If ObjectMetadata = Undefined Then
				ObjectMetadata = Data.Ref.Metadata();
			EndIf;
			
			Filter = Data.Ref;
			
			If Not ValueIsFilled(Filter) Then
				IsNew = True;
			EndIf;
			
		ElsIf CommonClientServer.HasAttributeOrObjectProperty(Data, "SourceRecordKey") Then	

			If ObjectMetadata = Undefined Then
				ObjectMetadata = Metadata.FindByType(TypeOf(Data.SourceRecordKey));	
			EndIf;
			Filter = New Structure;
			For Each Dimension In ObjectMetadata.Dimensions Do
				Filter.Insert(Dimension.Name, Data[Dimension.Name]);
			EndDo;
			
		Else
			ExceptionText = NStr("ru = 'Процедура InfobaseUpdate.MetadataAndFilterByData не может быть использована для этой формы.'; en = 'Cannot use InfobaseUpdate.MetadataAndFilterByData function in this form.'; pl = 'Nie może być zastosowana InfobaseUpdate.MetadataAndFilterByData funkcja w tym formularzu.';es_ES = 'El procedimiento InfobaseUpdate.MetadataAndFilterByData no puede ser usado para este formulario.';es_CO = 'El procedimiento InfobaseUpdate.MetadataAndFilterByData no puede ser usado para este formulario.';tr = 'Bu formda InfobaseUpdate.MetadataAndFilterByData fonksiyonu kullanılamaz.';it = 'Procedura Per Aggiornare Il Database Delle Informazioni.I metadati e la selezione dei dati non possono essere utilizzati per questo modulo.';de = 'Die Prozedur InfobaseUpdate.MetadataAndFilterByData kann für dieses Formular nicht verwendet werden.'");
		EndIf;
		
	Else
		
		If ObjectMetadata = Undefined Then
			ObjectMetadata = Data.Metadata();
		EndIf;
		
		If Common.IsRefTypeObject(ObjectMetadata) Then
			
			If Common.IsReference(DataType) Then
				Filter = Data;
			Else
				Filter = Data.Ref;
				
				If Data.IsNew() Then
					IsNew = True;
				EndIf;
			
			EndIf;
			
		ElsIf Common.IsInformationRegister(ObjectMetadata)
			AND ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			
			Filter = New Structure;
			For Each FilterItem In Data.Filter Do
				If FilterItem.Use Then 
					Filter.Insert(FilterItem.Name, FilterItem.Value);
				EndIf;
			EndDo;
			
		ElsIf Common.IsRegister(ObjectMetadata) Then
			If AdditionalParameters.IsRegisterRecords Then
				Filter = Data;
			Else
				Filter = Data.Filter.Recorder.Value;
			EndIf;
		Else
			ExceptionText = NStr("ru = 'Для этого типа метаданных не поддерживается анализ в функции InfobaseUpdate.MetadataAndFilterByData.'; en = 'The InfobaseUpdate.MetadataAndFilterByData function does not support analysis of this metadata type.'; pl = 'Funkcja InfobaseUpdate.MetadataAndFilterByData metadanych nie obsługuje analizy tego typu metadanych.';es_ES = 'Para este tipo de metadatos no se admite el análisis en la función InfobaseUpdate.MetadataAndFilterByData.';es_CO = 'Para este tipo de metadatos no se admite el análisis en la función InfobaseUpdate.MetadataAndFilterByData.';tr = 'Bu tür meta veri için InfobaseUpdate.AndFilterByData işlevinde analiz desteklenmiyor.';it = 'La funzione InfobaseUpdate.MetadataAndFilterByData non supporta l''analisi di questo tipo di metadati.';de = 'Für diese Art von Metadaten wird die Analyse in der Funktion InfobaseUpdate.MetadataAndFilterByData nicht unterstützt.'");
			Raise ExceptionText;
		EndIf;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("Data", Data);
	Result.Insert("Metadata", ObjectMetadata);
	Result.Insert("FullName", ObjectMetadata.FullName());
	Result.Insert("Filter", Filter);
	Result.Insert("IsNew", IsNew);
	
	Return Result;
EndFunction

// Mark passed objects for update.
// Note. It is not recommended that you pass to the Data parameter all the data to update at once as 
// big collections of Arrays or ValueTables type might take a significant amount of space on the 
// server and affect its performance.
//  It is recommended that you transfer data by batches about 1,000 objects at a time.
// 
//
// Parameters:
//  MainParameters - Structure - see InfobaseUpdate.MainProcessingMarkParameters. 
//  Data - Reference, Array, RecordSet - the data the changes to be recorded for.
//                    - ValueTable - independent information register dimension values. Requirements:
//                        - no changes with name "Node".
//                        - All register dimensions are included in the main filter.
//                        - The table contains only the columns that match the register dimension 
//                          names that are subject to process request.
//                        - During the update, the filter applied to the process request is applied 
//                          to sets to be recorded.
//                        - AdditionalParameters obtains the flag value and the full register name.
//  AdditionalParameters - Structure - see InfobaseUpdate.AdditionalProcessingMarkParameters. 
// 
Procedure MarkForProcessing(MainParameters, Data, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingMarkParameters();
	EndIf;
	
	If (TypeOf(Data) = Type("Array")
		Or TypeOf(Data) = Type("ValueTable"))
		AND Data.Count() = 0 Then
		Return;
	EndIf;
	
	Node = QueueRef(MainParameters.PositionInQueue);
	
	If AdditionalParameters.IsRegisterRecords Then
		
		Set = Common.ObjectManagerByFullName(AdditionalParameters.FullRegisterName).CreateRecordSet();
		
		If AdditionalParameters.SelectAllRecorders Then
			
			If TypeOf(Data) = Type("MetadataObject") Then
				DocumentMetadata = Data;
			ElsIf Common.IsReference(TypeOf(Data)) Then
				DocumentMetadata = Data.Metadata();
			Else
				ExceptionText = NStr("ru = 'Для регистрации всех регистраторов регистра необходимо в параметре ""Data"" передать MetadataObject:Document или DocumentRef.'; en = 'To register all register recorders, in the Data parameter, pass MetadataObject:Document or DocumentRef.'; pl = 'Dla rejestracji wszystkich rejestratorów rejestru należy w parametrze, przekazać MetadataObject:Dokument lub DocumentRef.';es_ES = 'Para registrar todos los registradores es necesario en el parámetro ""Datos"" transmitir MetadataObject:Document o DocumentRef.';es_CO = 'Para registrar todos los registradores es necesario en el parámetro ""Datos"" transmitir MetadataObject:Document o DocumentRef.';tr = 'Tüm sicil kaydediciler için ""Veriler"" parametresinde MetadataObject: Belge veya DocumentRef aktar.';it = 'Per registrare tutti i registrar del registro, è necessario passare un oggetto di metadati:documento o documento di riferimento nel parametro dati.';de = 'Um alle Registrierstellen des Registers zu registrieren, ist es erforderlich, im Parameter ""Daten"" die ObjektMetadaten:Dokument oder DokumentVerknüpfung zu übertragen.'");
				Raise ExceptionText;
			EndIf;
			FullDocumentName = DocumentMetadata.FullName();
			
			QueryText =
			"SELECT
			|	DocumentTable.Ref AS Ref
			|FROM
			|	#DocumentTable AS DocumentTable
			|WHERE
			|	DocumentTable.Posted";
			
			QueryText = StrReplace(QueryText, "#DocumentTable", FullDocumentName);
			Query = New Query;
			Query.Text = QueryText;
			
			RefsArray = Query.Execute().Unload().UnloadColumn("Ref");
			
			For Each ArrayElement In RefsArray Do
				Set.Filter.Recorder.Set(ArrayElement);
				RecordChanges(MainParameters, Node, Set, "SubordinateRegister", AdditionalParameters.FullRegisterName);
			EndDo;
			
		Else
			
			If TypeOf(Data) = Type("Array") Then
				Iterator = 0;
				Try
					For Each ArrayElement In Data Do
						If Iterator = 0 Then
							BeginTransaction();
						EndIf;
						Set.Filter.Recorder.Set(ArrayElement);
						RecordChanges(MainParameters, Node, Set, "SubordinateRegister", AdditionalParameters.FullRegisterName);
						Iterator = Iterator + 1;
						If Iterator = 1000 Then
							Iterator = 0;
							CommitTransaction();
						EndIf;
					EndDo;
					
					If Iterator <> 0 Then
						CommitTransaction();
					EndIf;
				Except
					RollbackTransaction();
					Raise;
				EndTry
			Else
				
				Set.Filter.Recorder.Set(Data);
				RecordChanges(MainParameters, Node, Set, "SubordinateRegister", AdditionalParameters.FullRegisterName);
				
			EndIf;
			
		EndIf;
	ElsIf AdditionalParameters.IsIndependentInformationRegister Then
		
		Set = Common.ObjectManagerByFullName(AdditionalParameters.FullRegisterName).CreateRecordSet();
		ObjectMetadata = Metadata.FindByFullName(AdditionalParameters.FullRegisterName);
		SetMissingFiltersInSet(Set, ObjectMetadata, Data);
		
		For Each TableRow In Data Do
			
			For Each Column In Data.Columns Do
				Set.Filter[Column.Name].Value = TableRow[Column.Name];
				Set.Filter[Column.Name].Use = True;
			EndDo;
			
			RecordChanges(MainParameters, Node, Set, "IndependentRegister", AdditionalParameters.FullRegisterName);
			
		EndDo;
	Else
		If TypeOf(Data) = Type("Array") Then
			Iterator = 0;
			Try
				For Each ArrayElement In Data Do
					If Iterator = 0 Then
						BeginTransaction();
					EndIf;
					RecordChanges(MainParameters, Node, ArrayElement, "Ref");
					Iterator = Iterator + 1;
					If Iterator = 1000 Then
						Iterator = 0;
						CommitTransaction();
					EndIf;
				EndDo;
				
				If Iterator <> 0 Then
					CommitTransaction();
				EndIf;
			Except
				RollbackTransaction();
				Raise;
			EndTry
		ElsIf Common.IsReference(TypeOf(Data)) Then
			RecordChanges(MainParameters, Node, Data, "Ref");
		Else
			If TypeOf(Data) = Type("MetadataObject") Then
				ExceptionText = NStr("ru = 'Не поддерживается регистрация к обновлению целиком объекта метаданных. Нужно обновлять конкретные данные.'; en = 'Registration of an entire metadata object for update is not supported. Please update specific data.'; pl = 'Nie jest obsługiwana rejestracja do aktualizacji w całości obiektu metadanych. Trzeba aktualizować konkretne dane.';es_ES = 'No se admite el registro a la actualización del objeto entero de metadatos. Hay que actualizar los datos en concreto.';es_CO = 'No se admite el registro a la actualización del objeto entero de metadatos. Hay que actualizar los datos en concreto.';tr = 'Meta veri nesnesinin tamamını güncelleştirmeye kayıt desteklenmiyor. Belirli verileri güncellemek gerekir.';it = 'Non è supportata la registrazione per aggiornare l''intero oggetto metadati. È necessario aggiornare i dati specifici.';de = 'Die Registrierung für die Aktualisierung des gesamten Metadatenobjekts wird nicht unterstützt. Bestimmte Daten müssen aktualisiert werden.'");
				Raise ExceptionText;
			EndIf;
			
			ObjectMetadata = Metadata.FindByType(TypeOf(Data));
			
			If Common.IsInformationRegister(ObjectMetadata)
				AND ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
				
				SetMissingFiltersInSet(Data, ObjectMetadata, Data.Filter);
				
			EndIf;
			RecordChanges(MainParameters, Node, Data, "IndependentRegister", ObjectMetadata.FullName());
		EndIf;
	EndIf;
	
EndProcedure

// Register passed recorders as the ones that require record update.
// 
// Parameters:
//  Parameters - Structure - see InfobaseUpdate.MainProcessingMarkParameters. 
//  Recorders - Array - a recorder ref array.
//  RegisterFullName - String - the full name of a register that requires update.
//
Procedure MarkRecordersForProcessing(Parameters, Recorders, FullRegisterName) Export
	
	AdditionalParameters = AdditionalProcessingMarkParameters();
	AdditionalParameters.IsRegisterRecords = True;
	AdditionalParameters.FullRegisterName = FullRegisterName;
	MarkForProcessing(Parameters, Recorders, AdditionalParameters);
	
EndProcedure

// Additional parameters for the data selected for processing.
// 
// Returns:
//  Structure - structure fields:
//     * SelectInParts - Boolean - select data to process in chunks.
//                              If documents are selected, the data chunks are formed considering 
//                              the document sorting (from newest to latest).  If register recorders 
//                              are selected and the full document name has been passed, the data 
//                              chunks are formed considering the recorder sorting (from newest to latest) . If the full document name has not been passed, the data chunks are formed considering the register sorting:
//                                      - Get maximum date for each recorder.
//                                      - If a register has no records, it goes on top.
//     * TemporaryTableName - String - the parameter is valid for methods that create temporary tables. 
//                                      If the name is not specified (the default scenario), the 
//                                      temporary table is created with the name specified in the method description.
//     * AdditionalDataSources - Map - the parameter is valid for methods that select recorders and 
//                                                      references to be processed. Map keys contain 
//                                                      the paths to document header attributes or 
//                                                      tabular parts attributes that connected to other tables (including
//                                                      implicit dot-separated connections). 
//                                                      Procedures check data lock for these tables 
//                                                      by the handlers with lowest positions in the queue. The name format is <AttributeName> or <TabularName>.<TabularPartAttributeName>.
//     * OrderingFields - Array - the name of independent information register fields used to 
//                                      organize a query result.
//
Function AdditionalProcessingDataSelectionParameters() Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("SelectInBatches", True);
	AdditionalParameters.Insert("TemporaryTableName", "");
	AdditionalParameters.Insert("AdditionalDataSources", New Map);
	AdditionalParameters.Insert("OrderingFields", New Array);
	
	Return AdditionalParameters;
	
EndFunction

// Creates temporary reference table that are not processed in the current queue and not locked by 
//  the lesser priority queues.
//  Table name: TTForProcessing<RegisterName>. For example, TTForProcessingStock.
//  Table columns.
//  * Recorder - DocumentRef.
//
// Parameters:
//  PositionInQueue - Number - the position in the processing queue where the handler is running.
//  FullDocumentName - String - the name of the document that requires record update. If the records 
//									are not based on the document data, the passed value is Undefined. In this case, the document table is not checked for lock.
//									For example, Document.GoodsReceipt.
//  RegisterFullName - String - the name of the register that requires record update.
//  	For example, AccumulationRegister.Stock.
//  TemporaryTablesManager - TemporaryTablesManager - the manager where a temporary table to be created.
//  AdditionalParameters - Structure - see InfobaseUpdate. AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  Structure - temporary table formation result:
//  * HasRecordsInTemporaryTable - Boolean - the created table has at least one record. There are 
//                                            two reasons records might be missing:
//												- All references have been processed or the references to be processed are locked by the lower-priority handlers.
//  * HasDataForProcessing - Boolean - the queue contains references to process.
//  * TemporaryTableName - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfRegisterRecordersToProcess(PositionInQueue, FullDocumentName, FullRegisterName, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	RegisterName = StrSplit(FullRegisterName,".",False)[1];
	
	CurrentQueue = QueueRef(PositionInQueue);
	
	If FullDocumentName = Undefined Then 
		If AdditionalParameters.SelectInBatches Then
			QueryText =
			"SELECT
			|	RegisterTableChanges.Recorder AS Recorder,
			|	MAX(ISNULL(RegisterTable.Period, DATETIME(3000, 1, 1))) AS Period
			|INTO TTToProcessRecorderFull
			|FROM
			|	#RegisterTableChanges AS RegisterTableChanges
			|		LEFT JOIN TTLockedRecorder AS TTLockedRecorder
			|		ON RegisterTableChanges.Recorder = TTLockedRecorder.Recorder
			|		LEFT JOIN #RegisterRecordsTable AS RegisterTable
			|		ON RegisterTableChanges.Recorder = RegisterTable.Recorder
			|		#ConnectionToAdditionalSourcesRegistersQueryText
			|WHERE
			|	RegisterTableChanges.Node = &CurrentQueue
			|	AND TTLockedRecorder.Recorder IS NULL
			|	AND &ConditionByAdditionalSourcesRegisters
			|
			|GROUP BY
			|	RegisterTableChanges.Recorder
			|
			|INDEX BY
			|	Recorder
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TTToProcessRecorderFull.Recorder AS Recorder
			|INTO #TTToProcessRecorder
			|FROM
			|	TTToProcessRecorderFull AS TTToProcessRecorderFull
			|WHERE
			|	TTToProcessRecorderFull.Recorder IN
			|			(SELECT TOP 10000
			|				TTToProcessRecorderFull.Recorder AS Recorder
			|			FROM
			|				TTToProcessRecorderFull AS TTToProcessRecorderFull
			|			ORDER BY
			|				TTToProcessRecorderFull.Period DESC)
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTLockedRecorder
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTToProcessRecorderFull";
			QueryText = StrReplace(QueryText,"#RegisterRecordsTable", FullRegisterName);	
		Else
			QueryText =
			"SELECT
			|	RegisterTableChanges.Recorder AS Recorder
			|INTO #TTToProcessRecorder
			|FROM
			|	#RegisterTableChanges AS RegisterTableChanges
			|		LEFT JOIN TTLockedRecorder AS TTLockedRecorder
			|		ON RegisterTableChanges.Recorder = TTLockedRecorder.Recorder
			|		#ConnectionToAdditionalSourcesRegistersQueryText
			|WHERE
			|	RegisterTableChanges.Node = &CurrentQueue
			|	AND TTLockedRecorder.Recorder IS NULL
			|	AND &ConditionByAdditionalSourcesRegisters
			|
			|INDEX BY
			|	Recorder
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTLockedRecorder";
		EndIf;
	Else
		DocumentName = StrSplit(FullDocumentName,".",False)[1];
		If AdditionalParameters.SelectInBatches Then
			QueryText =
			"SELECT
			|	RegisterTableChanges.Recorder AS Recorder
			|INTO TTToProcessRecorderFull
			|FROM
			|	#RegisterTableChanges AS RegisterTableChanges
			|		LEFT JOIN TTLockedRecorder AS TTLockedRecorder
			|		ON RegisterTableChanges.Recorder = TTLockedRecorder.Recorder
			|		LEFT JOIN TTLockedReference AS TTLockedReference
			|		ON RegisterTableChanges.Recorder = TTLockedReference.Ref
			|		#ConnectionToAdditionalSourcesByHeaderQueryText
			|		#ConnectionToAdditionalSourcesByTabularSectionQueryText
			|		#ConnectionToAdditionalSourcesRegistersQueryText
			|WHERE
			|	RegisterTableChanges.Node = &CurrentQueue
			|	AND RegisterTableChanges.Recorder REFS #FullDocumentName 
			|	AND TTLockedRecorder.Recorder IS NULL 
			|	AND TTLockedReference.Ref IS NULL 
			|	AND &ConditionByAdditionalSourcesReferences
			|	AND &ConditionByAdditionalSourcesRegisters
			|
			|INDEX BY
			|	Recorder
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TTToProcessRecorderFull.Recorder AS Recorder
			|INTO #TTToProcessRecorder
			|FROM
			|	TTToProcessRecorderFull AS TTToProcessRecorderFull
			|WHERE
			|	TTToProcessRecorderFull.Recorder IN
			|			(SELECT TOP 10000
			|				TTToProcessRecorderFull.Recorder AS Recorder
			|			FROM
			|				TTToProcessRecorderFull AS TTToProcessRecorderFull
			|					INNER JOIN #FullDocumentName AS DocumentTable
			|					ON
			|						TTToProcessRecorderFull.Recorder = DocumentTable.Ref
			|			ORDER BY
			|				DocumentTable.Date DESC)
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTLockedRecorder
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTLockedReference
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTToProcessRecorderFull";

		Else	
			QueryText =
			"SELECT
			|	RegisterTableChanges.Recorder AS Recorder
			|INTO #TTToProcessRecorder
			|FROM
			|	#RegisterTableChanges AS RegisterTableChanges
			|		LEFT JOIN TTLockedRecorder AS TTLockedRecorder
			|		ON RegisterTableChanges.Recorder = TTLockedRecorder.Recorder
			|		LEFT JOIN TTLockedReference AS TTLockedReference
			|		ON RegisterTableChanges.Recorder = TTLockedReference.Ref
			|		#ConnectionToAdditionalSourcesByHeaderQueryText
			|		#ConnectionToAdditionalSourcesByTabularSectionQueryText
			|		#ConnectionToAdditionalSourcesRegistersQueryText
			|WHERE
			|	RegisterTableChanges.Node = &CurrentQueue
			|	AND RegisterTableChanges.Recorder REFS #FullDocumentName 
			|	AND TTLockedRecorder.Recorder IS NULL 
			|	AND TTLockedReference.Ref IS NULL 
			|	AND &ConditionByAdditionalSourcesReferences
			|	AND &ConditionByAdditionalSourcesRegisters
			|
			|INDEX BY
			|	Recorder 
			|;
			|DROP
			|	TTLockedRecorder 
			|;
			|DROP
			|	TTLockedReference";
		EndIf;
		
		AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
		AdditionalParametersForTTCreation.TemporaryTableName = "TTLockedReference";
		CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullDocumentName, TempTablesManager, AdditionalParametersForTTCreation);
	EndIf;
	
	If IsBlankString(AdditionalParameters.TemporaryTableName) Then
		TemporaryTableName = "TTToProcess" + RegisterName;
	Else
		TemporaryTableName = AdditionalParameters.TemporaryTableName;
	EndIf;
	
	QueryText = StrReplace(QueryText, "#RegisterTableChanges", FullRegisterName + ".Changes");	
	QueryText = StrReplace(QueryText, "#TTToProcessRecorder", TemporaryTableName);
	
	AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
	AdditionalParametersForTTCreation.TemporaryTableName = "TTLockedRecorder";
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullRegisterName, TempTablesManager, AdditionalParametersForTTCreation);
	
	AddAdditionalSourceLockCheck(PositionInQueue, QueryText, FullDocumentName, FullRegisterName, TempTablesManager, True, AdditionalParameters);
	
	QueryText = StrReplace(QueryText, "#FullDocumentName", FullDocumentName);
		
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	QueryResult = Query.ExecuteBatch();
	
	Result = New Structure("HasRecordsInTemporaryTable,HasDataToProcess,TemporaryTableName", False, False, "");
	Result.TemporaryTableName = TemporaryTableName;
	Result.HasRecordsInTemporaryTable = QueryResult[0].Unload()[0].Count <> 0;
	
	If Result.HasRecordsInTemporaryTable Then
		Result.HasDataToProcess = True;
	Else
		Result.HasDataToProcess = HasDataToProcess(PositionInQueue, FullRegisterName);
	EndIf;	
	
	Return Result; 
	
EndFunction

// Returns a chunk of recorders that require record update. 
//  The input is the data registered in the queue. Data in the higher-priority queues is processed first.
//  Lock by other queues includes documents and registers.
//  If the full document name has been passed, the selected recorders are sorted by date (from newest to latest).
//  If the full document name has not been passed, the data chunks are formed considering the register sorting:
//				- Get maximum date for each recorder.
//				- If a register has no records, it goes on top.
// Parameters:
//  PositionInQueue - Number - the position in the queue the handler and the data it will process are assigned to.
//  FullDocumentName - String - the name of the document that requires record update. If the records 
//									are not based on the document data, the passed value is Undefined. In this case, the document table is not checked for lock.
//									For example, Document.GoodsReceipt.
//  RegisterFullName - String - the name of the register that requires record update.
//  	For example, AccumulationRegister.Stock.
//  AdditionalParameters - Structure - see InfobaseUpdate. AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  QueryResultSelection - the selection of recorders that require processing and selection fields:
//  * Recorder - DocumentRef.
//  * Period - Data - if the full document name is passed, the date of the document. Otherwise, the 
//						maximum period of the recorder.
//  * Posted - Boolean, Undefined - if the full document name is passed, contains the document Posted attribute value.
//										Otherwise, contains Undefined.
//
Function SelectRegisterRecordersToProcess(PositionInQueue, FullDocumentName, FullRegisterName, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	RegisterName = StrSplit(FullRegisterName,".",False)[1];
	
	CurrentQueue =  QueueRef(PositionInQueue);
	TempTablesManager = New TempTablesManager();
	
	If FullDocumentName = Undefined Then
		QueryText =
		"SELECT TOP 10000
		|	RegisterTableChanges.Recorder AS Recorder
		|FROM
		|	#RegisterTableChanges AS RegisterTableChanges
		|		LEFT JOIN #RegisterRecordsTable AS RegisterTable
		|		ON RegisterTableChanges.Recorder = RegisterTable.Recorder
		|		LEFT JOIN TTLockedRecorder AS TTLockedRecorder
		|		ON RegisterTableChanges.Recorder = TTLockedRecorder.Recorder
		|		#ConnectionToAdditionalSourcesRegistersQueryText
		|WHERE
		|	RegisterTableChanges.Node = &CurrentQueue
		|	AND TTLockedRecorder.Recorder IS NULL 
		|	AND &ConditionByAdditionalSourcesRegisters
		|
		|GROUP BY
		|	RegisterTableChanges.Recorder
		|
		|ORDER BY
		|	MAX(ISNULL(RegisterTable.Period, DATETIME(3000, 1, 1))) DESC";
		QueryText = StrReplace(QueryText, "#RegisterRecordsTable", FullRegisterName);	
	Else
		DocumentName = StrSplit(FullDocumentName,".",False)[1];
		QueryText =
		"SELECT TOP 10000
		|	RegisterTableChanges.Recorder AS Recorder
		|FROM
		|	#RegisterTableChanges AS RegisterTableChanges
		|		LEFT JOIN TTLockedRecorder AS TTLockedRecorder
		|		ON RegisterTableChanges.Recorder = TTLockedRecorder.Recorder
		|		LEFT JOIN TTLockedReference AS TTLockedReference
		|		ON RegisterTableChanges.Recorder = TTLockedReference.Ref
		|		INNER JOIN #FullDocumentName AS DocumentTable
		|			#ConnectionToAdditionalSourcesByHeaderQueryText
		|		ON RegisterTableChanges.Recorder = DocumentTable.Ref
		|		#ConnectionToAdditionalSourcesByTabularSectionQueryText
		|		#ConnectionToAdditionalSourcesRegistersQueryText
		|
		|WHERE
		|	RegisterTableChanges.Node = &CurrentQueue
		|	AND RegisterTableChanges.Recorder REFS #FullDocumentName 
		|	AND TTLockedRecorder.Recorder IS NULL 
		|	AND TTLockedReference.Ref IS NULL 
		|	AND &ConditionByAdditionalSourcesReferences
		|	AND &ConditionByAdditionalSourcesRegisters
		|
		|ORDER BY
		|	DocumentTable.Date DESC";
		AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
		AdditionalParametersForTTCreation.TemporaryTableName = "TTLockedReference";
		CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullDocumentName, TempTablesManager, AdditionalParametersForTTCreation);
	EndIf;
	
	QueryText = StrReplace(QueryText, "#RegisterTableChanges", FullRegisterName + ".Changes");	
	
	AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
	AdditionalParametersForTTCreation.TemporaryTableName = "TTLockedRecorder";
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullRegisterName, TempTablesManager, AdditionalParametersForTTCreation);
	
	If Not AdditionalParameters.SelectInBatches Then
		QueryText = StrReplace(QueryText, "SELECT TOP 10000","SELECT");
	EndIf;	
	
	AddAdditionalSourceLockCheck(PositionInQueue, QueryText, FullDocumentName, FullRegisterName, TempTablesManager, False, AdditionalParameters);
	
	QueryText = StrReplace(QueryText, "#FullDocumentName", FullDocumentName);
		
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	SelectionByRecorders = Query.Execute().Select();
		
	Return SelectionByRecorders;

EndFunction

// Returns a chunk of references that require processing.
//  The input is the data registered in the queue. Data in the higher-priority queues is processed first.
//	The returned document references are sorted by date (from newest to latest).
//
// Parameters:
//  PositionInQueue - Number - the position in the queue the handler and the data it will process 
//									are assigned to.
//  FullObjectName - String - the name of the object that require processing. For example, Document.GoodsReceipt.
//  AdditionalParameters - Structure - see InfobaseUpdate. AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  QueryResultSelection - the selection of references that require processing and selection fields:
//  * Ref - AnyRef.
//
Function SelectRefsToProcess(PositionInQueue, FullObjectName, AdditionalParameters = Undefined) Export
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	ObjectName = StrSplit(FullObjectName,".",False)[1];
	ObjectMetadata = Metadata.FindByFullName(FullObjectName);
	IsDocument = Common.IsDocument(ObjectMetadata)
				Or Common.IsTask(ObjectMetadata);
	
	QueryText =
	"SELECT TOP 10000
	|	ChangesTable.Ref
	|FROM
	|	#ObjectTableChanges AS ChangesTable
	|		LEFT JOIN #TTLockedReference AS TTLockedReference
	|		ON ChangesTable.Ref = TTLockedReference.Ref
	|		INNER JOIN #ObjectTable AS ObjectTable
	|			#ConnectionToAdditionalSourcesByHeaderQueryText
	|		ON ChangesTable.Ref = ObjectTable.Ref
	|		#ConnectionToAdditionalSourcesByTabularSectionQueryText
	|		#ConnectionToAdditionalSourcesRegistersQueryText
	|WHERE
	|	ChangesTable.Node = &CurrentQueue
	|	AND TTLockedReference.Ref IS NULL 
	|	AND &ConditionByAdditionalSourcesReferences
	|	AND &ConditionByAdditionalSourcesRegisters";
	If IsDocument Then
		QueryText = QueryText + "
		|
		|ORDER BY
		|	ObjectTable.Date DESC";
	EndIf;
	QueryText = QueryText + "
	|;
	|DROP
	|	#TTLockedReference"; 
	
	QueryText = StrReplace(QueryText, "#TTLockedReference","TTLocked" + ObjectName);
	QueryText = StrReplace(QueryText,"#ObjectTableChanges", FullObjectName + ".Changes");	
	QueryText = StrReplace(QueryText,"#ObjectTable", FullObjectName);	
	
	If Not AdditionalParameters.SelectInBatches Then
		QueryText = StrReplace(QueryText, "SELECT TOP 10000","SELECT");
	EndIf;	
	
	TempTablesManager = New TempTablesManager();
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullObjectName, TempTablesManager);
	
	AddAdditionalSourceLockCheck(PositionInQueue, QueryText, FullObjectName, Undefined, TempTablesManager, False, AdditionalParameters);
	CurrentQueue = QueueRef(PositionInQueue);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	SelectionByRefs = Query.Execute().Select();
		
	Return SelectionByRefs;
EndFunction

// Creates temporary reference table that are not processed in the current queue and not locked by 
//  the lesser priority queues.
//  Table name: TTForProcessing<ObjectName>, for instance, TTForProcessingProducts.
//  Table columns.
//  * Ref - AnyRef.
//
// Parameters:
//  PositionInQueue - Number - the position in the processing queue where the handler is running.
//  FullObjectName		 - String					 - full name of an object, for which the check is run (for instance, Catalog.Products).
//  TemporaryTablesManager - TemporaryTablesManager - the manager where a temporary table to be created.
//  AdditionalParameters - Structure - see InfobaseUpdate. AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  Structure - temporary table formation result:
//  * HasRecordsInTemporaryTable - Boolean - the created table has at least one record. There are 
//                                            two reasons records might be missing:
//												- All references have been processed or the references to be processed are locked by the lower-priority handlers.
//  * HasDataForProcessing - Boolean - the queue contains references to process.
//  * TemporaryTableName - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfRefsToProcess(PositionInQueue, FullObjectName, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	ObjectName = StrSplit(FullObjectName,".",False)[1];
	ObjectMetadata = Metadata.FindByFullName(FullObjectName);
	
	If AdditionalParameters.SelectInBatches Then
		
		IsDocument = Common.IsDocument(ObjectMetadata)
					Or Common.IsTask(ObjectMetadata);
		
		QueryText =
		"SELECT
		|	ChangesTable.Ref AS Ref";
		If IsDocument Then
			QueryText = QueryText + ",
			|	ObjectTable.Date AS Date";
		EndIf;
		QueryText = QueryText + "
		|INTO TTToProcessRefFull
		|FROM
		|	#ObjectTableChanges AS ChangesTable
		|		LEFT JOIN #TTLockedReference AS TTLockedReference
		|		ON ChangesTable.Ref = TTLockedReference.Ref
		|		INNER JOIN #ObjectTable AS ObjectTable
		|			#ConnectionToAdditionalSourcesByHeaderQueryText
		|		ON ChangesTable.Ref = ObjectTable.Ref
		|			#ConnectionToAdditionalSourcesByTabularSectionQueryText
		|			#ConnectionToAdditionalSourcesRegistersQueryText
		|WHERE
		|	ChangesTable.Node = &CurrentQueue
		|	AND TTLockedReference.Ref IS NULL 
		|	AND &ConditionByAdditionalSourcesReferences
		|	AND &ConditionByAdditionalSourcesRegisters
		|
		|INDEX BY
		|	Ref 
		|
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TTToProcessRefFull.Ref AS Ref
		|INTO #TTToProcessRef
		|FROM
		|	TTToProcessRefFull AS TTToProcessRefFull
		|WHERE
		|	TTToProcessRefFull.Ref IN
		|			(SELECT TOP 10000
		|				TTToProcessRefFull.Ref AS Ref
		|			FROM
		|				TTToProcessRefFull AS TTToProcessRefFull";
		If IsDocument Then
			QueryText = QueryText + "
			|			ORDER BY
			|				TTToProcessRefFull.Date DESC";
		EndIf;
		
		QueryText = QueryText + "
		|)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP #TTLockedReference
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TTToProcessRefFull"; 
		
	Else
		QueryText =
		"SELECT
		|	ChangesTable.Ref AS Ref
		|INTO #TTToProcessRef
		|FROM
		|	#ObjectTableChanges AS ChangesTable
		|		LEFT JOIN #TTLockedReference AS TTLockedReference
		|		ON ChangesTable.Ref = TTLockedReference.Ref
		|		INNER JOIN #ObjectTable AS ObjectTable
		|			#ConnectionToAdditionalSourcesByHeaderQueryText
		|		ON ChangesTable.Ref = ObjectTable.Ref
		|		#ConnectionToAdditionalSourcesByTabularSectionQueryText
		|		#ConnectionToAdditionalSourcesRegistersQueryText
		|WHERE
		|	ChangesTable.Node = &CurrentQueue
		|	AND TTLockedReference.Ref IS NULL
		|	AND &ConditionByAdditionalSourcesReferences
		|	AND &ConditionByAdditionalSourcesRegisters
		|
		|INDEX BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP #TTLockedReference"; 
	EndIf;
	
	If IsBlankString(AdditionalParameters.TemporaryTableName) Then
		TemporaryTableName = "TTToProcess" + ObjectName;
	Else
		TemporaryTableName = AdditionalParameters.TemporaryTableName;
	EndIf;
	
	QueryText = StrReplace(QueryText, "#TTLockedReference","TTLocked" + ObjectName);
	QueryText = StrReplace(QueryText, "#TTToProcessRef",TemporaryTableName);
	QueryText = StrReplace(QueryText,"#ObjectTableChanges", FullObjectName + ".Changes");	
	
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullObjectName, TempTablesManager);
	
	AddAdditionalSourceLockCheck(PositionInQueue, QueryText, FullObjectName, Undefined, TempTablesManager, True, AdditionalParameters);
	
	QueryText = StrReplace(QueryText,"#ObjectTable", FullObjectName);	
	
	CurrentQueue = QueueRef(PositionInQueue);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	QueryResult = Query.ExecuteBatch();
	
	Result = New Structure("HasRecordsInTemporaryTable,HasDataToProcess,TemporaryTableName", False, False,"");
	Result.TemporaryTableName = TemporaryTableName;
	Result.HasRecordsInTemporaryTable = QueryResult[0].Unload()[0].Count <> 0;
	
	If Result.HasRecordsInTemporaryTable Then
		Result.HasDataToProcess = True;
	Else
		Result.HasDataToProcess = HasDataToProcess(PositionInQueue, FullObjectName);
	EndIf;	
		
	Return Result;
	
EndFunction

// Returns the values of independent information register dimensions for processing.
// The input is the data registered in the queue. Data in the higher-priority queues is processed first.
//
// Parameters:
//  PositionInQueue - Number - the position in the queue the handler and the data it will process 
//                              are assigned to.
//  FullObjectName - String - the name of the object that require processing. For example, InformationRegister.ProductBarcodes.
//  AdditionalParameters - Structure - see InfobaseUpdate. AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  QueryResultSelection - the selection from dimension values that require processing. The field 
//                               names match the register dimenstion names. If a dimension is not in 
//                                the processing queue, this dimenstion selection value is blank.
//
Function SelectStandaloneInformationRegisterDimensionsToProcess(PositionInQueue, FullObjectName, AdditionalParameters = Undefined) Export
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	ObjectName = StrSplit(FullObjectName,".",False)[1];
	ObjectMetadata = Metadata.FindByFullName(FullObjectName);
		
	Query = New Query;
	QueryText =
	"SELECT TOP 10000
	|	&DimensionSelectionText
	|FROM
	|	#ObjectTableChanges AS ChangesTable
	|	LEFT JOIN #TTLockedDimensions AS TTLockedDimensions
	|	ON &DimensionJoinConditionText
	|   #ConnectionToAdditionalSourcesQueryText
	|WHERE
	|	ChangesTable.Node = &CurrentQueue
	|	AND &UnlockedFilterConditionText
	|	AND &ConditionByAdditionalSourcesReferences";
	
	If AdditionalParameters.OrderingFields.Count() > 0 Then
		OrderingText = "";
		For Each FieldName In AdditionalParameters.OrderingFields Do
			OrderingText = OrderingText + "ChangesTable." + FieldName + ", ";
		EndDo;
		QueryText = QueryText + "
		|ORDER BY
		| " + OrderingText + "TRUE";
	EndIf;
	
	DimensionSelectionText = "";
	DimensionJoinConditionText = "TRUE";
	UnlockedFilterConditionText = "TRUE";
	FirstDimension = True;
	For Each Dimension In ObjectMetadata.Dimensions Do
		
		If Not Dimension.MainFilter Then
			Continue;
		EndIf;
		
		DimensionSelectionText = DimensionSelectionText + "
		|	ChangesTable." + Dimension.Name + " AS " + Dimension.Name + ",";
		
		DimensionJoinConditionText = DimensionJoinConditionText + "
		|	AND (ChangesTable." + Dimension.Name + " = TTLockedDimensions." + Dimension.Name + "
		|		OR ChangesTable." + Dimension.Name + " = &EmptyDimensionValue"+ Dimension.Name + "
		|		OR TTLockedDimensions." + Dimension.Name + " = &EmptyDimensionValue"+ Dimension.Name + ")";
		
		Query.SetParameter("EmptyDimensionValue"+ Dimension.Name, Dimension.Type.AdjustValue()); 
		If FirstDimension Then
			UnlockedFilterConditionText =  "TTLockedDimensions." + Dimension.Name + " IS NULL ";
			FirstDimension = False;
		EndIf;
	EndDo;
	
	NonPeriodicFlag = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical;
	If ObjectMetadata.InformationRegisterPeriodicity <> NonPeriodicFlag
		AND ObjectMetadata.MainFilterOnPeriod Then
		DimensionSelectionText = DimensionSelectionText + "
			|	ChangesTable.Period AS Period,";
	EndIf;
	
	If IsBlankString(DimensionSelectionText) Then
		DimensionSelectionText = "*";
	Else
		DimensionSelectionText = Left(DimensionSelectionText, StrLen(DimensionSelectionText) - 1);
	EndIf;
	
	QueryText = StrReplace(QueryText, "&DimensionSelectionText", DimensionSelectionText);
	QueryText = StrReplace(QueryText, "&DimensionJoinConditionText", DimensionJoinConditionText);
	QueryText = StrReplace(QueryText, "&UnlockedFilterConditionText", UnlockedFilterConditionText);
	QueryText = StrReplace(QueryText, "#ObjectTableChanges", FullObjectName + ".Changes");
	QueryText = StrReplace(QueryText, "#TTLockedDimensions","TTLocked" + ObjectName);
	If Not AdditionalParameters.SelectInBatches Then
		QueryText = StrReplace(QueryText, "SELECT TOP 10000","SELECT");
	EndIf;
	
	TempTablesManager = New TempTablesManager();
	
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullObjectName, TempTablesManager);
	
	AddAdditionalSourceLockCheckForStandaloneRegister(PositionInQueue,
																				QueryText,
																				FullObjectName,
																				TempTablesManager,
																				AdditionalParameters);	
	
	CurrentQueue = QueueRef(PositionInQueue);
	
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	SelectionByDimensions = Query.Execute().Select();
		
	Return SelectionByDimensions;
EndFunction

// Creates a temporary table with values of an independent information register for processing.
//  Table name: TTForProcessing<ObjectName>. Example: TTForProcessingProductsBarcodes.
//  The table columns match the register dimensions. If processing a dimension is not required,
//	leaves the selection by the dimension blank.
//
// Parameters:
//  PositionInQueue - Number - the position in the processing queue where the handler is running.
//  FullObjectName		 - String					 - full name of an object, for which the check is run (for instance, Catalog.Products).
//  TemporaryTablesManager - TemporaryTablesManager - the manager where a temporary table to be created.
//  AdditionalParameters - Structure - see InfobaseUpdate. AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  Structure - temporary table formation result:
//  * HasRecordsInTemporaryTable - Boolean - the created table has at least one record. There are 
//                                            two reasons records might be missing:
//												- All references have been processed or the references to be processed are locked by the lower-priority handlers.
//  * HasDataForProcessing - Boolean - there is data for processing in the queue (subsequently, not everything is processed).
//  * TemporaryTableName - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfStandaloneInformationRegisterDimensionsToProcess(Queue, FullObjectName, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	ObjectName = StrSplit(FullObjectName,".",False)[1];
	ObjectMetadata = Metadata.FindByFullName(FullObjectName);
		                      
	Query = New Query;
	If AdditionalParameters.SelectInBatches Then
		QueryText =
		"SELECT
		|	&DimensionSelectionText
		|INTO TTToProcessDimensionsFull
		|FROM
		|	#ObjectTableChanges AS ChangesTable
		|		LEFT JOIN #TTLockedDimensions AS TTLockedDimensions
		|		ON (&DimensionJoinConditionText)
		|   #ConnectionToAdditionalSourcesQueryText
		|WHERE
		|	ChangesTable.Node = &CurrentQueue
		|	AND &UnlockedFilterConditionText
		|	AND &ConditionByAdditionalSourcesReferences
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 10000
		|	&DimensionSelectionText
		|INTO #TTToProcessDimensions
		|FROM
		|	TTToProcessDimensionsFull AS ChangesTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP #TTLockedDimensions
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TTToProcessDimensionsFull";
	Else
		QueryText =
		"SELECT
		|	&DimensionSelectionText
		|INTO #TTToProcessDimensions
		|FROM
		|	#ObjectTableChanges AS ChangesTable
		|	LEFT JOIN #TTLockedDimensions AS TTLockedDimensions
		|	ON &DimensionJoinConditionText
		|   #ConnectionToAdditionalSourcesQueryText
		|WHERE
		|	ChangesTable.Node = &CurrentQueue
		|	AND &UnlockedFilterConditionText
		|	AND &ConditionByAdditionalSourcesReferences
		|;
		|DROP
		|	#TTLockedDimensions";
	EndIf;
	DimensionSelectionText = "";
	DimensionJoinConditionText = "TRUE";
	
	FirstDimension = True;
	PeriodicRegister = 
		(ObjectMetadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical)
		AND ObjectMetadata.MainFilterOnPeriod;
	For Each Dimension In ObjectMetadata.Dimensions Do
		If Not Dimension.MainFilter Then
			Continue;
		EndIf;
		
		DimensionSelectionText = DimensionSelectionText + "
		|	ChangesTable." + Dimension.Name + " AS " + Dimension.Name + ",";
		
		DimensionJoinConditionText = DimensionJoinConditionText + "
		|	AND ChangesTable." + Dimension.Name + " = TTLockedDimensions." + Dimension.Name + "
		|		OR ChangesTable." + Dimension.Name + " = &EmptyDimensionValue"+ Dimension.Name + "
		|		OR TTLockedDimensions." + Dimension.Name + " = &EmptyDimensionValue"+ Dimension.Name;
		Query.SetParameter("EmptyDimensionValue"+ Dimension.Name, Dimension.Type.AdjustValue()); 
		
		If FirstDimension Then
			UnlockedFilterConditionText =  "TTLockedDimensions." + Dimension.Name + " IS NULL ";
			
			If PeriodicRegister Then
				DimensionSelectionText = DimensionSelectionText + "
					|	ChangesTable.Period AS Period,";
			EndIf;
			
			FirstDimension = False;
		EndIf;
	EndDo;
	
	DimensionSelectionText = Left(DimensionSelectionText, StrLen(DimensionSelectionText) - 1);
	
	If IsBlankString(AdditionalParameters.TemporaryTableName) Then
		TemporaryTableName = "TTToProcess" + ObjectName;
	Else
		TemporaryTableName = AdditionalParameters.TemporaryTableName;
	EndIf;
	
	QueryText = StrReplace(QueryText, "&DimensionSelectionText", DimensionSelectionText);
	QueryText = StrReplace(QueryText, "&DimensionJoinConditionText", DimensionJoinConditionText);
	QueryText = StrReplace(QueryText, "&UnlockedFilterConditionText", UnlockedFilterConditionText);
	QueryText = StrReplace(QueryText,"#ObjectTableChanges", FullObjectName + ".Changes");	
	QueryText = StrReplace(QueryText, "#TTLockedDimensions","TTLocked" + ObjectName);
	QueryText = StrReplace(QueryText, "#TTToProcessDimensions",TemporaryTableName);
	
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullObjectName, TempTablesManager);
	AddAdditionalSourceLockCheckForStandaloneRegister(Queue,
																				QueryText,
																				FullObjectName,
																				TempTablesManager,
																				AdditionalParameters);	
	
	CurrentQueue = QueueRef(Queue);
	
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	QueryResult = Query.ExecuteBatch();
	
	Result = New Structure("HasRecordsInTemporaryTable,HasDataToProcess,TemporaryTableName", False, False,"");
	Result.TemporaryTableName = TemporaryTableName;
	Result.HasRecordsInTemporaryTable = QueryResult[0].Unload()[0].Count <> 0;
	
	If Result.HasRecordsInTemporaryTable Then
		Result.HasDataToProcess = True;
	Else
		Result.HasDataToProcess = HasDataToProcess(Queue, FullObjectName);
	EndIf;	
		
	Return Result;
	
EndFunction

// Checks if there is unprocessed data.
//
// Parameters:
//  Queue    - Number        - a queue, to which a handler relates and in which data to process is 
//                              registered.
//             - Undefined - checked if general processing is complete;
//             - Array       - checked if there is data to be processed in the queues list.
//  FullObjectNameMetadata- String, MetadataObject - a full name of an object being processed or its 
//                              metadata. For example, "Document.GoodsReceipt"
//                            - Array - an array of full names of metadata objects; an array cannot 
//                              have independent information registers.
//  Filter - AnyReference, Structure, Undefined, Array - filters data to be checked.
//                              If passed Undefined - checked for the whole object type,
//                              If an object is a register subordinate to a recorder, then a 
//                                 reference to a recorder or an array of references is filtered.
//                              If an object is of a reference type, then either a reference or an array of references is filtered.
//                              If an object is an independent information register, then a structure containing values of dimensions is filtered.
//                              Structure key - dimension name, value - filter value (an array of values can be passed).
//
// Returns:
//  Boolean - True if not all data is processed.
//
Function HasDataToProcess(PositionInQueue, FullObjectNameMetadata, Filter = Undefined) Export
	
	If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
		If Not IsSubordinateDIBNode Then
			Return False;
		ElsIf GetFunctionalOption("DeferredMasterNodeUpdateCompleted") Then
			Return False;
		EndIf;
	EndIf;
	
	If TypeOf(FullObjectNameMetadata) = Type("String") Then
		FullNamesOfObjectsToProcess = StrSplit(FullObjectNameMetadata, ",");
	ElsIf TypeOf(FullObjectNameMetadata) = Type("Array") Then
		FullNamesOfObjectsToProcess = FullObjectNameMetadata;
	ElsIf TypeOf(FullObjectNameMetadata) = Type("MetadataObject") Then
		FullNamesOfObjectsToProcess = New Array;
		FullNamesOfObjectsToProcess.Add(FullObjectNameMetadata.FullName());
	Else
		ExceptionText = NStr("ru = 'Передан неправильный тип параметра ""FullObjectNameMetadata"" в функцию InfobaseUpdate.HasDataToProcess'; en = 'The FullObjectNameMetadata parameter passed to InfobaseUpdate.HasDataToProcess function has invalid type.'; pl = 'Parametr FullObjectNameMetadata został przekazany do funkcji InfobaseUpdate.HasDataToProcess ma nieprawidłowy typ.';es_ES = 'El parámetro FullObjectNameMetadata pasado a la función InfobaseUpdate.HasDataToProcess tiene un tipo no válido.';es_CO = 'El parámetro FullObjectNameMetadata pasado a la función InfobaseUpdate.HasDataToProcess tiene un tipo no válido.';tr = 'InfobaseUpdate.HasDataToProcess işlevinde ""FullObjectNameMetadata"" parametresinin türü yanlış aktarılmıştır.';it = 'Viene passato il tipo di parametro ""Nome Completo metadati oggetto"" errato alla funzione Aggiorna Database informazioni.Ci Sono Dati Da Elaborare.';de = 'Fehlerhafter Parametertyp ""FullObjectNameMetadata"" wurde an die Funktion InfobaseUpdate.HasDataToProcess übertragen'");
		Raise ExceptionText;
	EndIf;	
	
	Query = New Query;
	
	QueryTexts = New Array;
	FilterSet = False;
	
	For each TypeToProcess In FullNamesOfObjectsToProcess Do 
		
		If TypeOf(TypeToProcess) = Type("MetadataObject") Then
			ObjectMetadata = TypeToProcess;
			FullObjectName  = TypeToProcess.FullName();
		Else
			ObjectMetadata = Metadata.FindByFullName(TypeToProcess);
			FullObjectName  = TypeToProcess;
		EndIf;
		
		ObjectName = StrSplit(FullObjectName,".",False)[1];
		
		DataFilterCondition = "TRUE";
		
		If Common.IsRefTypeObject(ObjectMetadata) Then
			QueryText =
			"SELECT TOP 1
			|	ChangesTable.Ref AS Ref
			|FROM
			|	#ChangesTable AS ChangesTable
			|	LEFT JOIN #ObjectTable AS #ObjectName
			|		ON #ObjectName.Ref = ChangesTable.Ref
			|WHERE
			|	&NodeFilterCriterion
			|	AND &DataFilterCriterion
			|	AND NOT #ObjectName.Ref IS NULL";
			
			Query.SetParameter("Ref", Filter);
			
			If Filter <> Undefined Then
				DataFilterCondition = "ChangesTable.Ref IN (&Filter)";
			EndIf;
			
		ElsIf Common.IsInformationRegister(ObjectMetadata)
			AND ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			
			If FullNamesOfObjectsToProcess.Count() > 1 Then
				ExceptionText = NStr("ru = 'В массиве имен в параметре ""FullObjectNameMetadata"" в функцию InfobaseUpdate.FullObjectNameMetadata передан независимый регистр сведений.'; en = 'An independent information register is passed to the InfobaseUpdate.HasDataToProcess function in the FullObjectNameMetadata parameter (which has Array type).'; pl = 'Niezależny rejestr informacji został przekazany do funkcji InfobaseUpdate.HasDataToProcess w parametrze FullObjectNameMetadata (który jest typu Array).';es_ES = 'Se pasa un registro de información independiente a la función InfobaseUpdate.HasDataToProcess en el parámetro FullObjectNameMetadata (que tiene el tipo Matriz).';es_CO = 'Se pasa un registro de información independiente a la función InfobaseUpdate.HasDataToProcess en el parámetro FullObjectNameMetadata (que tiene el tipo Matriz).';tr = 'InfobaseUpdate.HasDataToProcess işlevinde ""FullObjectNameMetadata"" parametresinde isim masifinde bağımsız bilgi kaydı aktarıldı.';it = 'In una matrice di nomi nel parametro Nome Completo metadati oggetto nella funzione Aggiorna Database informazioni.Ci sono i dati per L''elaborazione trasferiti al Registro di informazioni indipendente.';de = 'Im Namensarray im Parameter ""FullObjectNameMetadata"" in der Funktion InfobaseUpdate.HasDataToProcess wurde ein unabhängiges Informationsregister übertragen.'");
				Raise ExceptionText;
			EndIf;	
			
			FilterSet = True;
			
			QueryText =
			"SELECT TOP 1
			|	&DimensionSelectionText
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|	AND &DataFilterCriterion";
			
			DimensionSelectionText = "";
			For Each Dimension In ObjectMetadata.Dimensions Do
				If Not Dimension.MainFilter Then
					Continue;
				EndIf;
				
				DimensionSelectionText = DimensionSelectionText + "
				|	ChangesTable." + Dimension.Name + " AS " + Dimension.Name + ",";
				
				If Filter <> Undefined Then
					DataFilterCondition = DataFilterCondition + "
					|	AND (ChangesTable." + Dimension.Name + " IN (&FilterValue" + Dimension.Name + ")
					|		OR ChangesTable." + Dimension.Name + " = &EmptyValue" + Dimension.Name + ")";
					
					If Filter.Property(Dimension.Name) Then
						Query.SetParameter("FilterValue" + Dimension.Name, Filter[Dimension.Name]);
					Else
						Query.SetParameter("FilterValue" + Dimension.Name, Dimension.Type.AdjustValue());
					EndIf;
					
					Query.SetParameter("EmptyValue" + Dimension.Name, Dimension.Type.AdjustValue());
				EndIf;
			EndDo;
			
			If IsBlankString(DimensionSelectionText) Then
				DimensionSelectionText = "*";
			Else
				DimensionSelectionText = Left(DimensionSelectionText, StrLen(DimensionSelectionText) - 1);
			EndIf;
			
			QueryText = StrReplace(QueryText, "&DimensionSelectionText", DimensionSelectionText);
			
		ElsIf Common.IsRegister(ObjectMetadata) Then
			
			QueryText =
			"SELECT TOP 1
			|	ChangesTable.Recorder AS Ref
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|	AND &DataFilterCriterion
			|	AND NOT Recorder.Ref IS NULL";
			
			If Filter <> Undefined Then
				DataFilterCondition = "ChangesTable.Recorder IN (&Filter)";
			EndIf;
			
		Else
			ExceptionText = NStr("ru = 'Для типа метаданных ""%ObjectMetadata%"" не поддерживается проверка в функции InfobaseUpdate.HasDataToProcess'; en = 'For %ObjectMetadata% metadata type, checks in InfobaseUpdate.HasDataToProcess function are not supported.'; pl = 'Dla typu metadanych ""%ObjectMetadata%"" nie jest obsługiwana weryfikacja w funkcji InfobaseUpdate.HasDataToProcess';es_ES = 'Para el tipo de datos ""%ObjectMetadata%"" no se admite la prueba en la función InfobaseUpdate.HasDataToProcess.';es_CO = 'Para el tipo de datos ""%ObjectMetadata%"" no se admite la prueba en la función InfobaseUpdate.HasDataToProcess.';tr = '%ObjectMetadata% tür metaveri için InfobaseUpdate.HasDataToProcess işlevinde doğrulama desteklenmiyor';it = 'Per il tipo di metadati %ObjectMetadata% non è supportato il controllo nella funzione InfobaseUpdate.HasDataToProcess.';de = 'Für den Metadatentyp ""%ObjectMetadata%"" wird die Überprüfung in der Funktion InfobaseUpdate.HasDataToProcess nicht unterstützt.'");
			ExceptionText = StrReplace(ExceptionText, "%ObjectMetadata%", String(ObjectMetadata)); 
			Raise ExceptionText;
		EndIf;
		
		QueryText = StrReplace(QueryText, "#ChangesTable", FullObjectName + ".Changes");
		QueryText = StrReplace(QueryText, "#ObjectTable", FullObjectName);
		QueryText = StrReplace(QueryText, "#ObjectName", ObjectName);
		QueryText = StrReplace(QueryText, "&DataFilterCriterion", DataFilterCondition);
		
		QueryTexts.Add(QueryText);
		
	EndDo;
	
	Connector = "
	|
	|UNION ALL
	|";

	QueryText = StrConcat(QueryTexts, Connector);
	
	If PositionInQueue = Undefined Then
		NodeFilterCondition = "	ChangesTable.Node REFS ExchangePlan.InfobaseUpdate ";
	Else
		NodeFilterCondition = "	ChangesTable.Node IN (&Nodes) ";
		If TypeOf(PositionInQueue) = Type("Array") Then
			Query.SetParameter("Nodes", PositionInQueue);
		Else
			Query.SetParameter("Nodes", QueueRef(PositionInQueue));
		EndIf;
	EndIf;
	
	QueryText = StrReplace(QueryText, "&NodeFilterCriterion", NodeFilterCondition);
	
	If Not FilterSet Then
		Query.SetParameter("Filter", Filter);
	EndIf;
		
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty(); 
	
EndFunction

// Checks if all data is processed.
//
// Parameters:
//  Queue    - Number        - a queue, to which a handler relates and in which data to process is 
//                              registered.
//             - Undefined - checked if general processing is complete;
//             - Array       - checked if there is data to be processed in the queues list.
//  FullObjectNameMetadata- String, MetadataObject - a full name of an object being processed or its 
//                              metadata. For example, "Document.GoodsReceipt"
//                            - Array - an array of full names of metadata objects; an array cannot 
//                              have independent information registers.
//  Filter - AnyReference, Structure, Undefined, Array - filters data to be checked.
//                              If passed Undefined - checked for the whole object type,
//                              If an object is a register subordinate to a recorder, then a 
//                                 reference to a recorder or an array of references is filtered.
//                              If an object is of a reference type, then either a reference or an array of references is filtered.
//                              If an object is an independent information register, then a structure containing values of dimensions is filtered.
//                              Structure key - dimension name, value - filter value (an array of values can be passed).
// 
// Returns:
//  Boolean - True if all data is processed.
//
Function DataProcessingCompleted(PositionInQueue, FullObjectNameMetadata, Filter = Undefined) Export
	
	Return Not HasDataToProcess(PositionInQueue, FullObjectNameMetadata, Filter);
	
EndFunction

// Checks if there is data locked by smaller queues.
//
// Parameters:
//  Queue - Number, Undefined - a queue, to which a handler relates and in which data to process is 
//                                  registered.
//  FullObjectNameMetadata - String, MetadataObject - a full name of an object being processed or 
//                                        its metadata. For example, "Document.GoodsReceipt"
//                             - Array - an array of full names of metadata objects; an array cannot 
//                                        have independent information registers.
// 
// Returns:
//  Boolean - True if processing of the object is locked by smaller queues.
//
Function HasDataLockedByPreviousQueues(PositionInQueue, FullObjectNameMetadata) Export
	
	Return HasDataToProcess(EarlierQueueNodes(PositionInQueue), FullObjectNameMetadata);
	
EndFunction

// Checks if data processing carried our by handlers of an earlier queue was finished.
//
// Parameters:
//  Queue    - Number        - a queue, to which a handler relates and in which data to process is 
//                              registered.
//             - Undefined - checked if general processing is complete;
//             - Array       - checked if there is data to be processed in the queues list.
//  Data     - AnyReference, RecordSet, Object, FormDataStructure - a reference to an object, an 
//                              object proper, or a set of records to be checked.
//                              If ExtendedParameters.IsRegisterRecords = True, then Data is a 
//                              recorder of a register specified in AdditionalParameters.
//  AdditionalParameters   - Structure - see InfobaseUpdate.AdditionalProcessingMarkParameters. 
//  MetadataAndFilter          - Structure - see InfobaseUpdate.MetadataAndFilterByData. 
// 
// Returns:
//  Boolean - True if the passed object is updated to a new version and can be changed.
//
Function CanReadAndEdit(PositionInQueue, Data, AdditionalParameters = Undefined, MetadataAndFilter = Undefined) Export
	
	If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		If Not Common.IsSubordinateDIBNode() Then
			Return True;
		ElsIf GetFunctionalOption("DeferredMasterNodeUpdateCompleted") Then
			Return True;
		EndIf;
	EndIf;
	
	If MetadataAndFilter = Undefined Then
		MetadataAndFilter = MetadataAndFilterByData(Data, AdditionalParameters);
	EndIf;
	
	If MetadataAndFilter.IsNew Then
		Return True;
	EndIf;
	
	If PositionInQueue = Undefined Then
		Return Not HasDataToProcess(Undefined, MetadataAndFilter.Metadata, MetadataAndFilter.Filter);
	Else
		Return Not HasDataToProcess(EarlierQueueNodes(PositionInQueue), MetadataAndFilter.Metadata, MetadataAndFilter.Filter);
	EndIf;
	
EndFunction

// Creates a temporary table containing locked data.
// Table name: TTLocked<ObjectName>, for example TTLockedProducts.
//  Table columns for objects of a reference type:
//      
//          * Ref
//      for registers subordinate to a recorder
//          * Recorder
//      for registers containing a direct record
//          * columns that correspond to dimensions of a register.
//
// Parameters:
//  Queue                 - Number, Undefined - the processing queue the current handler is being executed in.
//                             If passed Undefined, then checked in all queues.
//  FullObjectName        - String - full name of an object, for which the check is run (for 
//                             instance, , Catalog.Products).
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  AdditionalParameters - Structure - see InfobaseUpdate. 
//                             AdditionalProcessingDataSelectionParameters, the SelectInBatches 
//                             parameter is ignored, blocked data is always placed into a table in full.
//
// Returns:
//  Structure - structure with the following properties:
//     * HasRecordsInTemporaryTable - Boolean - the created table has at least one record.
//     * TemporaryTableName          - String - the name of the created table.
//
Function CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullObjectName, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	ObjectMetadata = Metadata.FindByFullName(FullObjectName);
	
	If Common.IsRefTypeObject(ObjectMetadata) Then
		If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
			QueryText =
			"SELECT DISTINCT
			|	&EmptyValue AS Ref
			|INTO #TemporaryTableName
			|WHERE
			|	FALSE";
			                                           
			Query.SetParameter("EmptyValue", ObjectMetadata.StandardAttributes.Ref.Type.AdjustValue()); 
		Else	
			QueryText =
			"SELECT DISTINCT
			|	ChangesTable.Ref AS Ref
			|INTO #TemporaryTableName
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|
			|INDEX BY
			|	Ref";
		EndIf;
	ElsIf Common.IsInformationRegister(ObjectMetadata)
		AND ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
		
		If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
			QueryText =
			"SELECT DISTINCT
			|	&DimensionSelectionText
			|INTO #TemporaryTableName
			|WHERE
			|	FALSE";
			DimensionSelectionText = "";
			For Each Dimension In ObjectMetadata.Dimensions Do
				If Not Dimension.MainFilter Then
					Continue;
				EndIf;
				
				DimensionSelectionText = DimensionSelectionText + "
				|	&EmptyDimensionValue"+ Dimension.Name + " AS " + Dimension.Name + ",";
				Query.SetParameter("EmptyDimensionValue"+ Dimension.Name, Dimension.Type.AdjustValue()); 
			EndDo;
			
		Else
			QueryText =
			"SELECT DISTINCT
			|	&DimensionSelectionText
			|INTO #TemporaryTableName
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion ";
			DimensionSelectionText = "";
			For Each Dimension In ObjectMetadata.Dimensions Do
				If Not Dimension.MainFilter Then
					Continue;
				EndIf;
				
				DimensionSelectionText = DimensionSelectionText + "
				|	ChangesTable." + Dimension.Name + " AS " + Dimension.Name + ",";
			EndDo;
		EndIf;
		
		NonPeriodicFlag = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical;
		If ObjectMetadata.InformationRegisterPeriodicity <> NonPeriodicFlag
			AND ObjectMetadata.MainFilterOnPeriod Then
			DimensionSelectionText = DimensionSelectionText + "
				|	ChangesTable.Period AS Period,";
		EndIf;
		
		If IsBlankString(DimensionSelectionText) Then
			DimensionSelectionText = "*";
		Else
			DimensionSelectionText = Left(DimensionSelectionText, StrLen(DimensionSelectionText) - 1);
		EndIf;
		
		QueryText = StrReplace(QueryText, "&DimensionSelectionText", DimensionSelectionText);
		
	ElsIf Common.IsRegister(ObjectMetadata) Then
		
		If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
			QueryText =
			"SELECT DISTINCT
			|	&EmptyValue AS Recorder
			|INTO #TemporaryTableName
			|WHERE
			|	FALSE";
			
			Query.SetParameter("EmptyValue", ObjectMetadata.StandardAttributes.Recorder.Type.AdjustValue()); 
			
		Else
			QueryText =
			"SELECT DISTINCT
			|	ChangesTable.Recorder AS Recorder
			|INTO #TemporaryTableName
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|
			|INDEX BY
			|	Recorder";
		EndIf;
		
	Else
		ExceptionText = NStr("ru = 'Для этого типа метаданных не поддерживается проверка в функции InfobaseUpdate.CreateTemporaryTableOfDataProhibitedFromReadingAndEditing.'; en = 'For this metadata type, checks in InfobaseUpdate.CreateTemporaryTableOfDataProhibitedFromReadingAndEditing function are not supported.'; pl = 'Dla tego typu metadanych, sprawdzanie InfobaseUpdate.CreateTemporaryTableOfDataProhibitedFromReadingAndEditing funkcji nie jest obsługiwane.';es_ES = 'Para este tipo de metadatos, no se admiten las comprobaciones en la función InfobaseUpdate.CreateTemporaryTableOfDataProhibitedFromReadingAndEditing.';es_CO = 'Para este tipo de metadatos, no se admiten las comprobaciones en la función InfobaseUpdate.CreateTemporaryTableOfDataProhibitedFromReadingAndEditing.';tr = 'Bu tür meta veri için VeriTabanıGüncellenmesi.SaltOkunurVerilerİçinGeçiciTabloyuOluştur işlevinde doğrulama desteklenmiyor.';it = 'Per questo tipo di metadati il controllo nella funzione InfobaseUpdate.CreateTemporaryTableOfDataProhibitedFromReadingAndEditing non è supportato.';de = 'Diese Art von Metadaten unterstützt keine Prüfung in der Funktion InfobaseUpdate.CreateTemporaryTableOfDataProhibitedFromReadingAndEditing.'");
		Raise ExceptionText;
	EndIf;
	
	If Not GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		
		If PositionInQueue = Undefined Then
			NodeFilterCondition = "	ChangesTable.Node REFS ExchangePlan.InfobaseUpdate ";
		Else
			NodeFilterCondition = "	ChangesTable.Node IN (&Nodes) ";
			Query.SetParameter("Nodes", EarlierQueueNodes(PositionInQueue));
		EndIf;	
		QueryText = StrReplace(QueryText, "&NodeFilterCriterion", NodeFilterCondition);
	
		QueryText = StrReplace(QueryText, "#ChangesTable", FullObjectName + ".Changes");
		
	EndIf;
	
	ObjectName = StrSplit(FullObjectName, ".")[1];
	
	If IsBlankString(AdditionalParameters.TemporaryTableName) Then
		TemporaryTableName =  "TTLocked"+ObjectName;
	Else
		TemporaryTableName = AdditionalParameters.TemporaryTableName;
	EndIf;
	
	QueryText = StrReplace(QueryText, "#TemporaryTableName", TemporaryTableName);
	
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	Result = New Structure("HasRecordsInTemporaryTable,TemporaryTableName", False, "");
	Result.TemporaryTableName = TemporaryTableName;
	Result.HasRecordsInTemporaryTable = QueryResult.Unload()[0].Count <> 0;
			
	Return Result;
	
EndFunction

// Creates a temporary table of blocked references.
//  Table name: TTLocked.
//  Table columns:
//    * Ref.
//
// Parameters:
//  Queue                 - Number, Undefined - the processing queue the current handler is being 
//                             executed in. If passed Undefined, then checked in all queues.
//  FullNamesOfObjects     - String, Array - full names of objects, for which the check is run (for 
//                             instance, Catalog.Products).
//                             It is allowed to pass objects of a reference type or registers subordinate to a recorder.
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  AdditionalParameters - Structure - see InfobaseUpdate. 
//                             AdditionalProcessingDataSelectionParameters, the SelectInBatches 
//                             parameter is ignored, blocked data is always placed into a table in full.
//
// Returns:
//  Structure - structure with the following properties:
//    * HasRecordsInTemporaryTable - Boolean - the created table has at least one record.
//    * TemporaryTableName          - String - the name of the created table.
//
Function CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing(PositionInQueue, FullNamesOfObjects, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		QueryText =
		"SELECT DISTINCT
		|	UNDEFINED AS Ref
		|INTO #TemporaryTableName
		|WHERE
		|	FALSE";
	Else	
		If TypeOf(FullNamesOfObjects) = Type("String") Then
			FullObjectNamesArray = StrSplit(FullNamesOfObjects,",",False);
		ElsIf TypeOf(FullNamesOfObjects) = Type("Array") Then 
			FullObjectNamesArray = FullNamesOfObjects;
		Else
			FullObjectNamesArray = New Array;
			FullObjectNamesArray.Add(FullNamesOfObjects);
		EndIf;
		
		QueryTextArray = New Array;
		
		HasRegisters = False;
		
		For Each TypeToProcess In FullObjectNamesArray Do
			
			If TypeOf(TypeToProcess) = Type("MetadataObject") Then
				ObjectMetadata = TypeToProcess;
				FullObjectName  = TypeToProcess.FullName();
			Else
				ObjectMetadata = Metadata.FindByFullName(TypeToProcess);
				FullObjectName  = TypeToProcess;
			EndIf;
			
			ObjectMetadata = Metadata.FindByFullName(FullObjectName);
			
			If Common.IsRefTypeObject(ObjectMetadata) Then
				If QueryTextArray.Count() = 0 Then
					QueryText =
					"SELECT DISTINCT
					|	ChangesTable.Ref AS Ref
					|//FirstQuery
					|FROM
					|	#ChangesTable AS ChangesTable
					|WHERE
					|	&NodeFilterCriterion";
				Else
					QueryText =
					"SELECT DISTINCT
					|	ChangesTable.Ref AS Ref
					|FROM
					|	#ChangesTable AS ChangesTable
					|WHERE
					|	&NodeFilterCriterion";	
				EndIf;
			ElsIf Common.IsRegister(ObjectMetadata) Then
				If QueryTextArray.Count() = 0 Then
					QueryText =
					"SELECT DISTINCT
					|	ChangesTable.Recorder AS Ref
					|//FirstQuery
					|FROM
					|	#ChangesTable AS ChangesTable
					|WHERE
					|	&NodeFilterCriterion";
				Else
					QueryText =
					"SELECT DISTINCT
					|	ChangesTable.Recorder AS Ref
					|FROM
					|	#ChangesTable AS ChangesTable
					|WHERE
					|	&NodeFilterCriterion";	
				EndIf;
				
				HasRegisters = True;
				
			Else
				ExceptionText = NStr("ru = 'Для типа метаданных ""%ObjectMetadata%"" не поддерживается проверка в функции InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing'; en = 'For %ObjectMetadata% metadata type, checks in InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing function are not supported.'; pl = 'W przypadku typu metadanych %ObjectMetadata% sprawdzanie funkcji InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing nie jest obsługiwane.';es_ES = 'Para el tipo de metadatos ""%ObjectMetadata%"" no se admite la prueba en la función InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing';es_CO = 'Para el tipo de metadatos ""%ObjectMetadata%"" no se admite la prueba en la función InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing';tr = '%ObjectMetadata% tür metaveri için InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing doğrulama desteklenmiyor.';it = 'Per tipo di metadati %ObjectMetadata% i controlli nella funzione InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing non sono supportati.';de = 'Für den Metadatentyp ""%ObjectMetadata%"" wird die Überprüfung in der Funktion InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing nicht unterstützt.'");
				ExceptionText = StrReplace(ExceptionText, "%ObjectMetadata%", String(ObjectMetadata)); 
				Raise ExceptionText;
			EndIf;
		
			QueryText = StrReplace(QueryText, "#ChangesTable", FullObjectName + ".Changes");
			
			QueryTextArray.Add(QueryText);
		EndDo;
		
		Connector = "
		|
		|UNION ALL
		|";
		
		QueryText = StrConcat(QueryTextArray, Connector); 
		
		If HasRegisters
			AND QueryTextArray.Count() > 1 Then
			QueryText =
			"SELECT DISTINCT
			|	NestedQuery.Ref AS Ref
			|INTO #TemporaryTableName
			|FROM
			|	(" + QueryText + ") AS NestedQuery
			|
			|INDEX BY
			|	Ref";
			QueryText = StrReplace(QueryText, "//FirstQuery", "");
		Else
			QueryText = QueryText + "
			|
			|INDEX BY
			|	Ref";
			QueryText = StrReplace(QueryText, "//FirstQuery", "INTO #TemporaryTableName");
		EndIf;
		
		If PositionInQueue = Undefined Then
			NodeFilterCondition = "	ChangesTable.Node REFS ExchangePlan.InfobaseUpdate ";
		Else
			NodeFilterCondition = "	ChangesTable.Node IN (&Nodes) ";
			Query.SetParameter("Nodes", EarlierQueueNodes(PositionInQueue));
		EndIf;	
		QueryText = StrReplace(QueryText, "&NodeFilterCriterion", NodeFilterCondition);
	EndIf;	
	
	If IsBlankString(AdditionalParameters.TemporaryTableName) Then
		TemporaryTableName =  "TTLocked";
	Else
		TemporaryTableName = AdditionalParameters.TemporaryTableName;
	EndIf;
	QueryText = StrReplace(QueryText, "#TemporaryTableName", TemporaryTableName);
	
	Query.Text = QueryText;
	QueryResult = Query.Execute();
	
	Result = New Structure("HasRecordsInTemporaryTable,TemporaryTableName", False, "");
	Result.TemporaryTableName = TemporaryTableName;
	Result.HasRecordsInTemporaryTable = QueryResult.Unload()[0].Count <> 0;
			
	Return Result;
	
EndFunction

// Creates a temporary table of changes in register dimensions subordinate to recorders for dimensions that have unprocessed recorders.
//  Calculation algorithm
//  - Determine locked recorders.
//  - Join with the main recorder table by these recorders.
//  - Get the values of changes from the main table.
//  - Perform the grouping.
//  Table name: TTLocked<ObjectName>, for example, TemporaryTableLockedStoredGoods
//  The table columns match the passed dimensions.
//
// Parameters:
//  Queue                 - Number, Undefined - the processing queue the current handler is being 
//                             executed in. If passed Undefined, then checked in all queues.
//                             
//  RegisterFullName       - String - the name of the register that requires record update.
//                             For example, AccumulationRegister.Stock.
//  Dimensions               - String, Array - the name of dimensions
//                             
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  AdditionalParameters - Structure - see InfobaseUpdate. 
//                             AdditionalProcessingDataSelectionParameters, the SelectInBatches 
//                             parameter is ignored, blocked data is always placed into a table in full.
//
// Returns:
//  Structure - structure with the following properties:
//   * HasRecordsInTemporaryTable - Boolean - the created table has at least one record.
//   * TemporaryTableName          - String - the name of the created table.
//
Function CreateTemporaryTableOfLockedDimensionValues(PositionInQueue, FullRegisterName, Dimensions, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If TypeOf(Dimensions) = Type("String") Then
		DimensionsArray = StrSplit(Dimensions, ",", False);
	Else
		DimensionsArray = Dimensions;
	EndIf;
	
	ObjectMetadata = Metadata.FindByFullName(FullRegisterName);
	
	If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		QueryText =
		"SELECT DISTINCT
		|	&DimensionValues
		|INTO #TemporaryTableName
		|WHERE
		|	FALSE";
		MeasurementsValues = "";
		For Each DimensionStr In DimensionsArray Do
			
			Dimension = ObjectMetadata.Dimensions.Find(DimensionStr);
			
			MeasurementsValues = MeasurementsValues + "
			|	&EmptyDimensionValue"+ Dimension.Name + " AS " + Dimension.Name + ",";
			Query.SetParameter("EmptyDimensionValue"+ Dimension.Name, Dimension.Type.AdjustValue()); 
			
		EndDo;
	Else
		
		QueryText =
		"SELECT DISTINCT
		|	&DimensionValues
		|INTO #TemporaryTableName
		|FROM
		|	#ChangesTable AS ChangesTable
		|		INNER JOIN #RegisterTable AS RegisterTable
		|		ON ChangesTable.Recorder = RegisterTable.Recorder
		|WHERE
		|	&NodeFilterCriterion";
		
		MeasurementsValues = "";
		For Each Dimension In DimensionsArray Do
			
			MeasurementsValues = MeasurementsValues + "
			|	RegisterTable." + Dimension + " AS " + Dimension + ","; 	
			
		EndDo;
		
		QueryText = StrReplace(QueryText, "#ChangesTable", FullRegisterName + ".Changes");
		QueryText = StrReplace(QueryText, "#RegisterTable", FullRegisterName);
		
		If PositionInQueue = Undefined Then
			NodeFilterCondition = "	ChangesTable.Node REFS ExchangePlan.InfobaseUpdate ";
		Else
			NodeFilterCondition = "	ChangesTable.Node IN (&Nodes) ";
			Query.SetParameter("Nodes", EarlierQueueNodes(PositionInQueue));
		EndIf;	
		
		QueryText = StrReplace(QueryText, "&NodeFilterCriterion", NodeFilterCondition);
		
		
	EndIf;
	
	ObjectName = StrSplit(FullRegisterName, ".")[1];
	If IsBlankString(AdditionalParameters.TemporaryTableName) Then
		TemporaryTableName =  "TTLocked" + ObjectName;
	Else
		TemporaryTableName = AdditionalParameters.TemporaryTableName;
	EndIf;
	QueryText = StrReplace(QueryText, "#TemporaryTableName", TemporaryTableName);
	
	MeasurementsValues = Left(MeasurementsValues, StrLen(MeasurementsValues) - 1);
	QueryText = StrReplace(QueryText, "&DimensionValues", MeasurementsValues);
	Query.Text = QueryText;
	QueryResult = Query.Execute();
	
	Result = New Structure("HasRecordsInTemporaryTable,TemporaryTableName", False, "");
	Result.TemporaryTableName = TemporaryTableName;
	Result.HasRecordsInTemporaryTable = QueryResult.Unload()[0].Count <> 0;
			
	Return Result;
	
EndFunction

// The function is used for checking objects in opening forms and before recording.
// It can be used as a function for checking by default in case there is enough logics - blocked 
// objects are registered on the InfobaseUpdate exchange plan nodes.
//
// Parameters:
//  MetadataAndFilter - Structure - see InfobaseUpdate.MetadataAndFilterByData. 
//
// Returns:
//  Boolean - True if the object is updated and available for changing.
//
Function DataUpdatedForNewApplicationVersion(MetadataAndFilter) Export
	
	Return CanReadAndEdit(Undefined, MetadataAndFilter.Data,,MetadataAndFilter); 
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Checks if the infobase update is required when the configuration version is changed.
//
// Returns:
//   Boolean - True if an update is required.
//
Function InfobaseUpdateRequired() Export
	
	Return InfobaseUpdateInternalCached.InfobaseUpdateRequired();
	
EndFunction

// Returns True if the infobase is being updated.
//
// Returns:
//   Boolean - True if an update is in progress.
//
Function InfobaseUpdateInProgress() Export
	
	If Common.DataSeparationEnabled()
		AND Not Common.SeparatedDataUsageAvailable() Then
		Return InfobaseUpdateRequired();
	EndIf;
	
	Return SessionParameters.IBUpdateInProgress;
	
EndFunction

// Returns True if the function is called from the update handler.
// For any type of an update handler - exclusive, seamless, or deferred.
//
// Parameters:
//  HandlerExecutionMode - String - Deferred, Seamless, Exclusive or a combination of these variants 
//                               separated by commas. If given, only a call from update handlers 
//                               from the stated execution mode is checked.
//
Function IsCallFromUpdateHandler(HandlerExecutionMode = "") Export
	
	ExecutionMode = SessionParameters.UpdateHandlerParameters.ExecutionMode;
	If Not ValueIsFilled(ExecutionMode) Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(HandlerExecutionMode) Then
		Return True;
	EndIf;
	
	Return (StrFind(HandlerExecutionMode, ExecutionMode) > 0);
	
EndFunction

// Returns an empty table of update handlers and initial infobase filling handlers.
//
// Returns:
//   ValueTable - a table with the following columns:
//    1) For all types of update handlers:
//
//     * InitialFilling - Boolean - if True, then a handler is started on a launch with an empty base.
//     * Version - String - for example, "2.1.3.39". Configuration version number. The handler is 
//                                      executed when the configuration migrates to this version number.
//                                      If an empty string is specified, this handler is intended 
//                                      for initial filling only (when the InitialFilling parameter is specified).
//     * Procedure - String - the full name of an update handler or initial filling handler.
//                                      For example, "MEMInfobaseUpdate.FillNewAttribute"
//                                      Must be an export procedure.
//     * ExecutionMode - String - update handler run mode. The following values are available:
//                                      Exclusive, Deferred, Nonexclusive. If this value is not 
//                                      specified, the handler is considered exclusive.
//
//    2. For SaaS update handlers:
//
//     * SharedData - Boolean - if True, the handler is executed prior to other handlers that use 
//                                      shared data.
//                                      Is is allowed to specify it only for handlers with Exclusive or Seamless execution mode.
//                                      If the True value is specified for a handler with a Deferred 
//                                      execution mode, an exception will be brought out.
//     * HandlerManagement - Boolean - if True, then the handler has a parameter of a structure type 
//                                          which has a property.
//                                      SeparatedHandlers - the table of values characterized by the 
//                                                               structure retuned by this function.
//                                      In this case the version column is ignored. If separated 
//                                      handler execution is required, you have to add a row with 
//                                      the description of the handler procedure.
//                                      Makes sense only for required (Version = *) update handlers 
//                                      having a SharedData flag set.
//
//    3) For deferred update handlers:
//
//     * Comment         - String - details for actions executed by an update handler.
//     * ID       - UUID - it must be filled in only for deferred update handlers and not required 
//                                                 for others. Helps to identify a handler in case 
//                                                 it was renamed.
//     
//     * LockedItems - String - it must be filled in only for deferred update handlers and not 
//                                      required for others. Full names of objects separated by 
//                                      commas. These names must be locked from changing until data processing procedure is finalized.
//                                      If it is not empty, then the CheckProcedure property must also be filled in.
//     * CheckProcedure   - String - it must be filled in only for deferred update handlers and not 
//                                      required for others. Name of a function that defines if data 
//                                      processing procedure is finalized for the passed object.
//                                      If the passed object is fully processed, it must aquire the True value.
//                                      Called from the InfobaseUpdate.CheckObjectProcessed procedure.
//                                      Parameters that are passed to the function:
//                                         Parameters - Structure - see InfobaseUpdate. MetadataAndFilterByData.
//
//    4) For update handlers in libraries (configurations) with a parallel mode of deferred handlers execution:
//
//     * UpdateDataFillingProcedure - String - the procedure for registering data to be updated by 
//                                      this handler must be specified.
//     * RunOnlyInMasterNode - Boolean - only for deferred update handlers with a Parallel execution mode.
//                                      Specify as True if an update handler must be executed only 
//                                      in the master DIB node.
//     * RunAlsoInSubordinateDIBNodeWithFilters - Boolean - only for deferred update handlers with 
//                                      the Parallel execution mode,
//                                      Specify as True if an update handler must also be executed 
//                                      in the subordinate DIB node using filters.
//     * ObjectsToRead              - String - Objects to be read by the update handler while processing data.
//     * ObjectsToChange            - String - Objects to be changed by the update handler while processing data.
//     * ExecutionPriorities         - ValueTable - Table of execution priorities for deferred 
//                                      handlers changing or reading the same data. For more 
//                                      information, see the commentary to the InfobaseUpdate.HandlerExecutionPriorities function.
//
//    5) For inner use:
//
//     * ExecuteInMandatoryGroup - Boolean - specify this parameter if the handler must be executed 
//                                      in the group that contains handlers for the "*" version.
//                                      You can change the order of handlers in the group by 
//                                      changing their priorities.
//     * Priority           - Number - for inner use.
//
//    6) Obsolete, used for backwards compatibility (not to be specified for new handlers):
//
//     * ExclusiveMode    - Undefined, Boolean - if Undefined, the handler is executed 
//                                      unconditionally in the exclusive mode.
//                                      For handlers that execute migration to a specific version (Version <> "*"):
//                                        False   - handler execution does not require an exclusive mode.
//                                        True - handler execution requires an exclusive mode.
//                                      For required update handlers (Version = "*"):
//                                        False   - handler execution does not require an exclusive mode.
//                                        True - handler execution may require an exclusive mode.
//                                                 A parameter of structure type with ExclusiveMode 
//                                                 property (of Boolean type) is passed to such handlers.
//                                                 To execute the handler in exclusive mode, set 
//                                                 this parameter to True. In this case the handler 
//                                                 must perform the required update operations. 
//                                                 Changing the parameter in the handler body is ignored.
//                                                 To execute the handler in nonexclusive mode, set 
//                                                 this parameter to False. In this case the handler 
//                                                 must not make any changes to the infobase.
//                                                 If the analysis reveals that a handler needs to 
//                                                 change infobase data, set the parameter value to.
//                                                 True and stop execution of a handler.
//                                                 In this case nonexclusive infobase update is 
//                                                 canceled and an error message with a 
//                                                 recommendation to perform the update in exclusive mode is displayed.
//
Function NewUpdateHandlerTable() Export
	
	Handlers = New ValueTable;
	// Common properties.
	Handlers.Columns.Add("InitialFilling", New TypeDescription("Boolean"));
	Handlers.Columns.Add("Version",    New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("Procedure", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("ExecutionMode", New TypeDescription("String"));
	// For libraries.
	Handlers.Columns.Add("ExecuteInMandatoryGroup", New TypeDescription("Boolean"));
	Handlers.Columns.Add("Priority", New TypeDescription("Number", New NumberQualifiers(2)));
	// For the service model.
	Handlers.Columns.Add("SharedData",             New TypeDescription("Boolean"));
	Handlers.Columns.Add("HandlerManagement", New TypeDescription("Boolean"));
	// For deferred update handlers.
	Handlers.Columns.Add("Comment", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("ID", New TypeDescription("UUID"));
	Handlers.Columns.Add("CheckProcedure", New TypeDescription("String"));
	Handlers.Columns.Add("ObjectsToLock", New TypeDescription("String"));
	// For the Parallel execution mode of the deferred update.
	Handlers.Columns.Add("UpdateDataFillingProcedure", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("DeferredProcessingQueue",  New TypeDescription("Number", New NumberQualifiers(4)));
	Handlers.Columns.Add("ExecuteInMasterNodeOnly",  New TypeDescription("Boolean"));
	Handlers.Columns.Add("RunAlsoInSubordinateDIBNodeWithFilters",  New TypeDescription("Boolean"));
	Handlers.Columns.Add("ObjectsToRead", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("ObjectsToChange", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("ExecutionPriorities");
	
	// Obsolete. Reverse compatibility with edition 2.2.
	Handlers.Columns.Add("Optional");
	Handlers.Columns.Add("ExclusiveMode");
	
	Return Handlers;
	
EndFunction

// Returns the empty table of execution priorities for deferred handlers changing or reading the 
// same data. For using update handlers in descriptions.
//
// Returns:
//  ValueTable - a table with the following columns:
//    * Order       - String - execution order for a current handler in relation to other handlers.
//                               Possible variants - "Before", "After", "Any".
//    * ID - UUID - an ID of a procedure to establish relation with.
//    * Procedure     - String - full name of a procedure to establish relation with.
//
// Example:
//  Priority = HandlerExecutionPriorities().Add();
//  Priority.Order = "Before";
//  Priority.Procedure = "Document.CustomerOrder.UpdateDataForMigrationToNewVersion";
//
Function HandlerExecutionPriorities() Export
	
	Priorities = New ValueTable;
	Priorities.Columns.Add("Order", New TypeDescription("String", , New StringQualifiers(0)));
	Priorities.Columns.Add("ID");
	Priorities.Columns.Add("Procedure", New TypeDescription("String", , New StringQualifiers(0)));
	
	Return Priorities;
	
EndFunction

// Executes handlers from the UpdateHandlers list for LibraryID library update to IBMetadataVersion 
// version.
//
// Parameters:
//   LibraryID  - String       - configuration name or a library ID.
//   IBMetadataVersion       - String       - metadata version to be updated to.
//   UpdateHandlers    - Match - list of update handlers.
//   SeamlessUpdate    - Boolean       - True if an update is seamless.
//   HandlerExecutionProgress - Structure    - has the following properties:
//       * TotalHandlers     - String - a total number of handlers being executed.
//       * HandlersCompleted - Boolean - a number of completed handlers.
//
// Returns:
//   ValueTree   - executed update handlers.
//
Function ExecuteUpdateIteration(Val LibraryID, Val IBMetadataVersion, 
	Val UpdateHandlers, Val HandlerExecutionProgress, Val SeamlessUpdate = False) Export
	
	UpdateIteration = InfobaseUpdateInternal.UpdateIteration(LibraryID, 
		IBMetadataVersion, UpdateHandlers);
		
	Parameters = New Structure;
	Parameters.Insert("HandlerExecutionProgress", HandlerExecutionProgress);
	Parameters.Insert("NonexclusiveUpdate", SeamlessUpdate);
	Parameters.Insert("InBackground", False);
	
	Return InfobaseUpdateInternal.ExecuteUpdateIteration(UpdateIteration, Parameters);
	
EndFunction

// Execute noninteractive infobase update.
// This function is intended for calling through an external connection.
// When calling the method containing extensions which modify the configuration role, the exception will follow.
// 
// To be used in other libraries and configurations.
//
// Parameters:
//  ExecuteDeferredHandlers - Boolean - if True, then a deferred update will be executed in the 
//    default update mode. Only for a client-server mode.
//
// Returns:
//  String -  update hadlers execution flag:
//           "Done", "NotRequired", "ExclusiveModeSettingError".
//
Function UpdateInfobase(ExecuteDeferredHandlers = False) Export
	
	Return InfobaseUpdateInternalServerCall.UpdateInfobase(,, ExecuteDeferredHandlers);
	
EndFunction

// Returns a table of subsystem versions used in the configuration.
// The procedure is used for batch import and export of information about subsystem versions.
//
// Returns:
//   ValueTable - a table with columns:
//     * SubsystemName - String - name of a subsystem.
//     * Version        - String - version of a subsystem.
//
Function SubsystemsVersions() Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	SubsystemsVersions.SubsystemName AS SubsystemName,
	|	SubsystemsVersions.Version AS Version
	|FROM
	|	InformationRegister.SubsystemsVersions AS SubsystemsVersions";
	
	Return Query.Execute().Unload();

EndFunction 

// Sets all subsystem versions.
// The procedure is used for batch import and export of information about subsystem versions.
//
// Parameters:
//   SubsystemVersions - ValueTable - a table containing the following columns:
//     * SubsystemName - String - name of a subsystem.
//     * Version        - String - version of a subsystem.
//
Procedure SetSubsystemVersions(SubsystemsVersions) Export

	RecordSet = InformationRegisters.SubsystemsVersions.CreateRecordSet();
	
	For each Version In SubsystemsVersions Do
		NewRecord = RecordSet.Add();
		NewRecord.SubsystemName = Version.SubsystemName;
		NewRecord.Version = Version.Version;
		NewRecord.IsMainConfiguration = (Version.SubsystemName = Metadata.Name);
	EndDo;
	
	RecordSet.Write();

EndProcedure

// Get configuration or parent configuration (library) version that is stored in the infobase.
// 
//
// Parameters:
//  LibraryID - String - a configuration name or a library ID.
//
// Returns:
//   String   - version.
//
// Example:
//   IBConfigurationVersion = IBVersion(Metadata.Name);
//
Function IBVersion(Val LibraryID) Export
	
	Return InfobaseUpdateInternal.IBVersion(LibraryID);
	
EndFunction

// Writes a configuration or parent configuration (library) version to the infobase.
//
// Parameters:
//  LibraryID - String - configuration (library) name or parent configuration (library) name,
//  VersionNumber             - String - version number.
//  IsMainConfiguration - Boolean - a flag indicating that the LibraryID corresponds to the configuration name.
//
Procedure SetIBVersion(Val LibraryID, Val VersionNumber, Val IsMainConfiguration) Export
	
	InfobaseUpdateInternal.SetIBVersion(LibraryID, VersionNumber, IsMainConfiguration);
	
EndProcedure

// Registers a new subsystem in the SubsystemVersions information register.
// For instance, it can be used to create a subsystem on the basis of already existing metadata 
// without using initial filling handlers.
// If the subsystem is registered, succeeding registration will not be performed.
// This method can be called from the BeforeInfobaseUpdate procedure of the common module 
// InfobaseUpdateOverridable.
//
// Parameters:
//  SubsystemName - String - name of a subsystem in the form set in the common module.
//                           InfobaseUpdateXXX.
//                           For example - "StandardSubsystems".
//  VersionNumber   - String - full number of a version the subsystem must be registered for.
//                           If the number is not stated, it will be registered for a version "0.0.0.1". 
//                           It is necessary to indicate if only last handlers should be executed or all of them.
//
Procedure RegisterNewSubsystem(SubsystemName, VersionNumber = "") Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	| SubsystemsVersions.SubsystemName AS SubsystemName
	|FROM
	| InformationRegister.SubsystemsVersions AS SubsystemsVersions";
	
	ConfigurationSubsystems = Query.Execute().Unload().UnloadColumn("SubsystemName");
	
	If ConfigurationSubsystems.Count() > 0 Then
		// This is not the first launch of a program
		If ConfigurationSubsystems.Find(SubsystemName) = Undefined Then
			Record = InformationRegisters.SubsystemsVersions.CreateRecordManager();
			Record.SubsystemName = SubsystemName;
			Record.Version = ?(VersionNumber = "", "0.0.0.1", VersionNumber);
			Record.Write();
		EndIf;
	EndIf;
	
	Information = InfobaseUpdateInternal.InfobaseUpdateInfo();
	ItemIndex = Information.NewSubsystems.Find(SubsystemName);
	If ItemIndex <> Undefined Then
		Information.NewSubsystems.Delete(SubsystemName);
		InfobaseUpdateInternal.WriteInfobaseUpdateInfo(Information);
	EndIf;
	
EndProcedure

// Returns a queue number of a deferred update handler by its full name or a UUID.
// 
//
// Parameters:
//  NameOrID - String, UUID - full name of deferred handler or its ID.
//                         For more information, see NewUpdateHandlerTable, description of  
//                        properties for Procedure and ID.
//
// Returns:
//  Number, Undefined - queue number of a passed handler. If a handler is not found, the Undefined 
//                        value will be returned.
//
Function DeferredUpdateHandlerQueue(NameOrID) Export
	
	Result = InfobaseUpdateInternalCached.DeferredUpdateHandlerQueue();
	
	If TypeOf(NameOrID) = Type("UUID") Then
		QueueByID = Result["ByID"];
		Return QueueByID[NameOrID];
	Else
		QueueByName = Result["ByName"];
		Return QueueByName[NameOrID];
	EndIf;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete: no longer required as the actions are executed automatically by an update feature.
// 
// Removes a deferred handler from the handler execution queue for the new version.
// It is recommended for use in cases, such as switching from a deferred handler execution mode to 
// an exclusive (seamless) one.
// To perform this action, add a new separate update handler of a
// "Seamless" execution mode and a "SharedData = False" flag, and place a call for this method in it.
//
// Parameters:
//  HandlerName - String - full procedure name of a deferred handler.
//
Procedure DeleteDeferredHandlerFromQueue(HandlerName) Export
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	
	SelectedHandler = UpdateInfo.HandlersTree.Rows.FindRows(New Structure("HandlerName", HandlerName), True);
	If SelectedHandler <> Undefined AND SelectedHandler.Count() > 0 Then
		
		For Each RowHandler In SelectedHandler Do
			RowHandler.Parent.Rows.Delete(RowHandler);
		EndDo;
		
	EndIf;
	
	For Each UpdateStep In UpdateInfo.DeferredUpdatePlan Do
		StepHandlers = UpdateStep.Handlers;
		Index = 0;
		HandlerFound = False;
		For Each HandlerDetails In StepHandlers Do
			If HandlerDetails.HandlerName = HandlerName Then
				HandlerFound = True;
				Break;
			EndIf;
			Index = Index + 1;
		EndDo;
		
		If HandlerFound Then
			StepHandlers.Delete(Index);
			Break;
		EndIf;
	EndDo;
	
	InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure AddAdditionalSourceLockCheck(PositionInQueue, QueryText, FullObjectName, FullRegisterName, TempTablesManager, IsTemporaryTableCreation, AdditionalParameters)
	
	If AdditionalParameters.AdditionalDataSources.Count() = 0 Then
				
		QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesByHeaderQueryText", "");
		QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesByTabularSectionQueryText", "");
		QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesReferences", "TRUE");
		QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRegisters", "TRUE");
		QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesRegistersQueryText", "");
	
	Else	
		
		AdditionalSourcesRefs = New Array;
		AdditionalSourcesRegisters = New Array;
		
		For Each KeyValue In AdditionalParameters.AdditionalDataSources Do
			
			DataSource = KeyValue.Key;
			
			If Upper(Left(DataSource,7)) = "REGISTER"
				AND StrFind(DataSource,".") <> 0 Then
				AdditionalSourcesRegisters.Add(DataSource);
			Else
				AdditionalSourcesRefs.Add(DataSource);
			EndIf;
			
		EndDo;
		
		#Region AdditionalSourcesRefs
		
		If AdditionalSourcesRefs.Count() > 0 Then
			
			If FullObjectName = Undefined Then
				ExceptionText = NStr("ru = 'Ошибка вызова функции %FunctionName%: не передано имя документа, но переданы дополнительные источники данных.'; en = 'Error in %FunctionName% function call: no document name was passed but additional data sources were passed.'; pl = 'Błąd wezwania funkcji%FunctionName%: nie przekazano nazwy dokumentu, ale są przekazane dodatkowe źródła danych.';es_ES = 'Error al llamar la función %FunctionName%: no se ha transmitido el nombre de documento, no han sido transmitidos las fuentes adicionales de datos.';es_CO = 'Error al llamar la función %FunctionName%: no se ha transmitido el nombre de documento, no han sido transmitidos las fuentes adicionales de datos.';tr = '%FunctionName% işlevin çağrı hatası: belge adı aktarılamadı, ancak ek veri kaynakları aktarıldı.';it = 'Errore di chiamata della funzione %FunctionName%: nono è stato trasmesso il nome del documento ma sono state trasmesse fonti di dati aggiuntive.';de = 'Fehler beim Aufruf der Funktion %FunctionName%: Der Dokumentname wurde nicht übertragen, es wurden jedoch zusätzliche Datenquellen übertragen.'");
				ExceptionText = StrReplace(ExceptionText, "%FunctionName%", "InfobaseUpdate.AddAdditionalSourceLockCheck");
				Raise ExceptionText;
			EndIf;
			
			DocumentMetadata = Metadata.FindByFullName(FullObjectName);
			ConnectionToAdditionalSourcesByHeaderQueryText = "";
			ConnectionToAdditionalSourcesByTabularSectionQueryText = "";
			ConnectionToAdditionalSourcesByTabularSectionQueryTexts = New Map;
			ConditionByAdditionalSourcesRefs = "TRUE";
			
			ConditionByAdditionalSourcesRefsTabularSection = "FALSE";
			
			TemporaryTablesOfLockedAdditionalSources = New Map;
			
			For Each DataSource In AdditionalSourcesRefs Do
				
				If StrFind(DataSource, ".") > 0 Then
					NameParts = StrSplit(DataSource, ".");
					TSName = NameParts[0];
					AttributeName = NameParts[1];
				Else
					TSName = "";
					AttributeName = DataSource;
				EndIf;
				
				If ValueIsFilled(TSName) Then
					SourceTypes = DocumentMetadata.TabularSections[TSName].Attributes[AttributeName].Type.Types();
				Else
					SourceTypes = DocumentMetadata.Attributes[AttributeName].Type.Types();
				EndIf;	
				
				For Each SourceType In SourceTypes Do
					
					If IsPrimitiveType(SourceType) Then
						Continue;
					EndIf;
					
					If ValueIsFilled(TSName)
						AND StrFind(ConnectionToAdditionalSourcesByTabularSectionQueryText, "AS DocumentTabularSection" + TSName) = 0 Then
						
						If FullRegisterName <> Undefined Then
							
							ConnectionToAdditionalSourcesByTabularSectionQueryText = ConnectionToAdditionalSourcesByTabularSectionQueryText + "
							|		INNER JOIN #FullDocumentName." + TSName + " AS DocumentTabularSection" + TSName + "
							|#ConnectionToAdditionalSourcesByTabularSectionQueryText" + TSName + "
							|		ON RegisterTableChanges.Recorder = DocumentTabularSection" + TSName + ".Ref
							|";
							
						Else
							
							ConnectionToAdditionalSourcesByTabularSectionQueryText = ConnectionToAdditionalSourcesByTabularSectionQueryText + "
							|		INNER JOIN #FullDocumentName." + TSName + " AS DocumentTabularSection" + TSName + "
							|#ConnectionToAdditionalSourcesByTabularSectionQueryText" + TSName + "
							|		ON ChangesTable.Ref = DocumentTabularSection" + TSName + ".Ref
							|";
							
						EndIf;
					EndIf;
					
					SourceMetadata = Metadata.FindByType(SourceType);
					
					LockedAdditionalSourceTTName = TemporaryTablesOfLockedAdditionalSources.Get(SourceMetadata);
					
					If LockedAdditionalSourceTTName = Undefined Then
						FullSourceName = SourceMetadata.FullName();
						LockedAdditionalSourceTTName = "TTLocked" + StrReplace(FullSourceName,".","_");
						
						AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
						AdditionalParametersForTTCreation.TemporaryTableName = LockedAdditionalSourceTTName;
						CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, FullSourceName, TempTablesManager, AdditionalParametersForTTCreation);
						
						TemporaryTablesOfLockedAdditionalSources.Insert(SourceMetadata, LockedAdditionalSourceTTName);
						
					EndIf;
					
					If ValueIsFilled(TSName) Then
						
						ConnectionToAdditionalSourcesByTSTSNameQueryText = ConnectionToAdditionalSourcesByTabularSectionQueryTexts.Get(TSName);
						
						If ConnectionToAdditionalSourcesByTSTSNameQueryText = Undefined Then
							ConnectionToAdditionalSourcesByTSTSNameQueryText = "";
						EndIf;
						
						ConnectionToAdditionalSourcesByTSTSNameQueryText = ConnectionToAdditionalSourcesByTSTSNameQueryText + "
						|			LEFT JOIN #TTName AS #TempTableSynonym
						|			ON DocumentTabularSection" + TSName + "." + AttributeName + " = #TempTableSynonym.Ref";
						
						ConnectionToAdditionalSourcesByTSTSNameQueryText = StrReplace(ConnectionToAdditionalSourcesByTSTSNameQueryText,
																					"#TTName",
																					LockedAdditionalSourceTTName);
						LockedAdditionalSourceTTSynonym = LockedAdditionalSourceTTName + TSName + AttributeName;															 
						ConnectionToAdditionalSourcesByTSTSNameQueryText = StrReplace(ConnectionToAdditionalSourcesByTSTSNameQueryText,
																					"#TempTableSynonym",
																					LockedAdditionalSourceTTSynonym);
						ConnectionToAdditionalSourcesByTabularSectionQueryTexts.Insert(TSName, ConnectionToAdditionalSourcesByTSTSNameQueryText);
						
						ConditionByAdditionalSourcesRefsTabularSection = ConditionByAdditionalSourcesRefsTabularSection + "
						|	OR NOT " + LockedAdditionalSourceTTSynonym + ".Ref IS NULL ";
					Else
						If FullRegisterName <> Undefined Then
							ConnectionToAdditionalSourcesByHeaderQueryText = ConnectionToAdditionalSourcesByHeaderQueryText + "
							|			LEFT JOIN #TTName AS #TempTableSynonym
							|			ON DocumentTable." + AttributeName + " = #TempTableSynonym.Ref";
						Else
							ConnectionToAdditionalSourcesByHeaderQueryText = ConnectionToAdditionalSourcesByHeaderQueryText + "
							|			LEFT JOIN #TTName AS #TempTableSynonym
							|			ON ObjectTable." + AttributeName + " = #TempTableSynonym.Ref";
						EndIf;
						ConnectionToAdditionalSourcesByHeaderQueryText = StrReplace(ConnectionToAdditionalSourcesByHeaderQueryText,
																					"#TTName",
																					LockedAdditionalSourceTTName);
						LockedAdditionalSourceTTSynonym = LockedAdditionalSourceTTName + "Header";															 
						ConnectionToAdditionalSourcesByHeaderQueryText = StrReplace(ConnectionToAdditionalSourcesByHeaderQueryText,
																					"#TempTableSynonym",
																					LockedAdditionalSourceTTSynonym);
					
						ConditionByAdditionalSourcesRefs = ConditionByAdditionalSourcesRefs + "
						|	AND " + LockedAdditionalSourceTTSynonym + ".Ref IS NULL ";
					EndIf;
				EndDo;
				
			EndDo;
			
			If Not IsBlankString(ConnectionToAdditionalSourcesByTabularSectionQueryText) Then
				For Each JoinText In ConnectionToAdditionalSourcesByTabularSectionQueryTexts Do
					
					ConnectionToAdditionalSourcesByTabularSectionQueryText = StrReplace(ConnectionToAdditionalSourcesByTabularSectionQueryText,
					"#ConnectionToAdditionalSourcesByTabularSectionQueryText" + JoinText.Key,
					JoinText.Value);
					
				EndDo;
				
				If FullRegisterName <> Undefined Then
					LockedSourcesTemporaryTableByTabularSectionQueryText =
					"SELECT DISTINCT
					|	RegisterTableChanges.Recorder AS Ref
					|INTO LockedByTabularSection
					|FROM
					|	#ChangesTable AS RegisterTableChanges
					|       #ConnectionToAdditionalSourcesByTabularSectionQueryText
					|WHERE
					|	&ConditionByAdditionalSourcesReferencesTabularSection";
				Else
					LockedSourcesTemporaryTableByTabularSectionQueryText =
					"SELECT DISTINCT
					|	ChangesTable.Ref AS Ref
					|INTO LockedByTabularSection
					|FROM
					|	#ChangesTable AS ChangesTable
					|       #ConnectionToAdditionalSourcesByTabularSectionQueryText
					|WHERE
					|	&ConditionByAdditionalSourcesReferencesTabularSection";
				EndIf;
				
				LockedSourcesTemporaryTableByTabularSectionQueryText = StrReplace(LockedSourcesTemporaryTableByTabularSectionQueryText,
																				"#ConnectionToAdditionalSourcesByTabularSectionQueryText",
																				ConnectionToAdditionalSourcesByTabularSectionQueryText);
				
				LockedSourcesTemporaryTableByTabularSectionQueryText = StrReplace(LockedSourcesTemporaryTableByTabularSectionQueryText,
																				"&ConditionByAdditionalSourcesReferencesTabularSection",
																				ConditionByAdditionalSourcesRefsTabularSection);
				If FullRegisterName <> Undefined Then
					LockedSourcesTemporaryTableByTabularSectionQueryText = StrReplace(LockedSourcesTemporaryTableByTabularSectionQueryText,
																					"#ChangesTable",
																					FullRegisterName + ".Changes");	
				Else
					LockedSourcesTemporaryTableByTabularSectionQueryText = StrReplace(LockedSourcesTemporaryTableByTabularSectionQueryText,
																					"#ChangesTable",
																					FullObjectName + ".Changes");	
				EndIf;																
				
				LockedSourcesTemporaryTableByTabularSectionQueryText = StrReplace(LockedSourcesTemporaryTableByTabularSectionQueryText,
																				"#FullDocumentName",
																				FullObjectName);
				Query = New Query;
				Query.Text = LockedSourcesTemporaryTableByTabularSectionQueryText;
				Query.TempTablesManager = TempTablesManager;
				Query.Execute();
				
				If FullRegisterName <> Undefined Then
					ConnectionToAdditionalSourcesByTabularSectionQueryText = "
					|		LEFT JOIN LockedByTabularSection AS LockedByTabularSection 
					|		ON RegisterTableChanges.Recorder = LockedByTabularSection.Ref
					|";
				Else
					ConnectionToAdditionalSourcesByTabularSectionQueryText = "
					|		LEFT JOIN LockedByTabularSection AS LockedByTabularSection 
					|		ON ChangesTable.Ref = LockedByTabularSection.Ref
					|";
				EndIf;																
				
				ConditionByAdditionalSourcesRefs = ConditionByAdditionalSourcesRefs + "
				|	AND LockedByTabularSection.Ref IS NULL ";
				
				TemporaryTablesOfLockedAdditionalSources.Insert("LockedByTabularSection", "LockedByTabularSection");
			EndIf;
			
			If ValueIsFilled(ConnectionToAdditionalSourcesByHeaderQueryText) Then 
				If IsTemporaryTableCreation
					AND FullRegisterName <> Undefined Then
					ConnectionToAdditionalSourcesByHeaderQueryText = StrReplace("
					|		INNER JOIN #FullDocumentName AS DocumentTable
					|       	#ConnectionToAdditionalSourcesByHeaderQueryText
					|		ON RegisterTableChanges.Recorder = DocumentTable.Ref",
					"#ConnectionToAdditionalSourcesByHeaderQueryText",
					ConnectionToAdditionalSourcesByHeaderQueryText);
				EndIf;
			EndIf;	
				
			DropTemporaryTableQueryTextTemplate = "
			|DROP
			|	#TTName
			|";
			
			QueryTexts = New Array;
			QueryTexts.Add(QueryText);
			
			For Each KeyValue In TemporaryTablesOfLockedAdditionalSources Do
				
				DropTemporaryTableQueryText = StrReplace(DropTemporaryTableQueryTextTemplate, "#TTName", KeyValue.Value);
				
				QueryTexts.Add(DropTemporaryTableQueryText);
				
			EndDo;
			
			QueryText = StrConcat(QueryTexts, ";");
			QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesByHeaderQueryText", ConnectionToAdditionalSourcesByHeaderQueryText);
			QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesByTabularSectionQueryText", ConnectionToAdditionalSourcesByTabularSectionQueryText);
			QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesReferences", ConditionByAdditionalSourcesRefs);
			QueryText = StrReplace(QueryText, "#FullDocumentName", FullObjectName);
		Else
			QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesByHeaderQueryText", "");
			QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesByTabularSectionQueryText", "");
			QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesReferences", "TRUE");
		EndIf;
		#EndRegion
		
		#Region AdditionalSourcesRegisters

		If AdditionalSourcesRegisters.Count() > 0 Then
			
			ConnectionToAdditionalSourcesRegistersQueryText = "";
			ConditionByAdditionalSourcesRegisters = "TRUE";
			
			TemporaryTablesOfLockedAdditionalSources = New Map;
			
			For Each DataSource In AdditionalSourcesRegisters Do
				
				SourceMetadata = Metadata.FindByFullName(DataSource);
				
				If Common.IsInformationRegister(SourceMetadata)
					AND SourceMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					
					ExceptionText = NStr("ru = 'Регистр %DataSource% независимый. Поддерживается проверка только по регистрам, подчиненным регистраторам.'; en = 'The %DataSource% register is independent. Checks can only be performed for registers that are subordinate to recorders.'; pl = 'Rejestr %DataSource% jest niezależny. Jest obsługiwana weryfikacja tylko według rejestrów, podporządkowanych do rejestratorów.';es_ES = 'El registro %DataSource% es independiente. Se admite la prueba solo por registros subordinados a los registradores.';es_CO = 'El registro %DataSource% es independiente. Se admite la prueba solo por registros subordinados a los registradores.';tr = '%DataSource% kaydedicisi bağımsız. Sadece kaydedicilere bağlı kayıtlara göre doğrulama destekleniyor.';it = 'Il registro %DataSource% è indipendente. I controlli possono essere eseguiti solo per i registri subordinati ai registratori.';de = 'Registrieren Sie %DataSource% unabhängig. Es wird nur für Register unterstützt, die Registrierstellen untergeordnet sind.'");
					ExceptionText = StrReplace(ExceptionText, "%DataSource%",DataSource);
					Raise ExceptionText;
				EndIf;
				
				LockedAdditionalSourceTTName = TemporaryTablesOfLockedAdditionalSources.Get(SourceMetadata);
				
				If LockedAdditionalSourceTTName = Undefined Then
					LockedAdditionalSourceTTName = "TTLocked" + StrReplace(DataSource,".","_");
					
					AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
					AdditionalParametersForTTCreation.TemporaryTableName = LockedAdditionalSourceTTName;
					CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(PositionInQueue, DataSource, TempTablesManager, AdditionalParametersForTTCreation);
					
					TemporaryTablesOfLockedAdditionalSources.Insert(SourceMetadata, LockedAdditionalSourceTTName);
					
				EndIf;
				
				If FullRegisterName <> Undefined Then
					ConnectionToAdditionalSourcesRegistersQueryText = ConnectionToAdditionalSourcesRegistersQueryText + "
					|			LEFT JOIN #TTName AS #TTName
					|			ON RegisterTableChanges.Recorder = #TTName.Recorder";
				Else
					ConnectionToAdditionalSourcesRegistersQueryText = ConnectionToAdditionalSourcesRegistersQueryText + "
					|			LEFT JOIN #TTName AS #TTName
					|			ON ObjectTable.Ref = #TTName.Recorder";
				EndIf;
				ConnectionToAdditionalSourcesRegistersQueryText = StrReplace(ConnectionToAdditionalSourcesRegistersQueryText,
					"#TTName", LockedAdditionalSourceTTName);
					
				ConditionByAdditionalSourcesRegisters = ConditionByAdditionalSourcesRegisters + "
				|	AND " + LockedAdditionalSourceTTName + ".Recorder IS NULL ";
				
			EndDo;	
			
			DropTemporaryTableQueryTextTemplate = "
			|DROP
			|	#TTName
			|";
			
			QueryTexts = New Array;
			QueryTexts.Add(QueryText);
			
			For Each KeyValue In TemporaryTablesOfLockedAdditionalSources Do
				
				DropTemporaryTableQueryText = StrReplace(DropTemporaryTableQueryTextTemplate, "#TTName", KeyValue.Value);
				
				QueryTexts.Add(DropTemporaryTableQueryText);
				
			EndDo;
			
			QueryText = StrConcat(QueryTexts, ";");
			QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesRegistersQueryText", ConnectionToAdditionalSourcesRegistersQueryText);
			QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRegisters", ConditionByAdditionalSourcesRegisters);
		Else
			QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRegisters", "TRUE");
			QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesRegistersQueryText", "");
		EndIf;
		#EndRegion
	EndIf;	
EndProcedure

Function IsPrimitiveType(TypeToCheck)
	
	If TypeToCheck = Type("Undefined")
		Or TypeToCheck = Type("Boolean")
		Or TypeToCheck = Type("String")
		Or TypeToCheck = Type("Number")
		Or TypeToCheck = Type("Date")
		Or TypeToCheck = Type("UUID") Then
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

Procedure AddAdditionalSourceLockCheckForStandaloneRegister(PositionInQueue, QueryText, FullRegisterName, TempTablesManager, AdditionalParameters)
	
	If AdditionalParameters.AdditionalDataSources.Count() = 0 Then
		
		QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesQueryText", "");
		QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesReferences", "TRUE");
	
	Else
		
		RegisterMetadata = Metadata.FindByFullName(FullRegisterName);
		ConnectionToAdditionalSourcesQueryText = "";
		ConditionByAdditionalSourcesRefs = "TRUE";
		
		DropTemporaryTableQueryTextTemplate = "
		|DROP
		|	#TTName
		|";
		
		QueryTexts = New Array;
		QueryTexts.Add(QueryText);
		
		For Each KeyValue In AdditionalParameters.AdditionalDataSources Do
			
			DataSource = KeyValue.Key;
			
			SourceTypes = RegisterMetadata.Dimensions[DataSource].Type.Types();
			MetadataObjectArray = New Array;
			
			For Each SourceType In SourceTypes Do
				
				If IsPrimitiveType(SourceType) Then
					Continue;
				EndIf;
				
				MetadataObjectArray.Add(Metadata.FindByType(SourceType));
				
			EndDo;
			
			AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
			TemporaryTableName = "TTLocked" + DataSource;
			AdditionalParametersForTTCreation.TemporaryTableName = TemporaryTableName;
			
			CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing(PositionInQueue, MetadataObjectArray, TempTablesManager, AdditionalParametersForTTCreation);
			
			ConnectionToAdditionalSourcesQueryText = ConnectionToAdditionalSourcesQueryText + "
			|		LEFT JOIN " + TemporaryTableName + " AS " + TemporaryTableName + "
			|		ON ChangesTable." + DataSource + " = " + TemporaryTableName + ".Ref";
			
			ConditionByAdditionalSourcesRefs = ConditionByAdditionalSourcesRefs + "
			|		AND "  + TemporaryTableName + ".Ref IS NULL ";
			
			DropTemporaryTableQueryText = StrReplace(DropTemporaryTableQueryTextTemplate, "#TTName", TemporaryTableName);
			QueryTexts.Add(DropTemporaryTableQueryText);
			
		EndDo;
		
		QueryText = StrConcat(QueryTexts, ";");
		
		QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesQueryText", ConnectionToAdditionalSourcesQueryText);
		QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesReferences", ConditionByAdditionalSourcesRefs);

	EndIf;
EndProcedure

Procedure SetMissingFiltersInSet(Set, SetMetadata, FiltersToSet)
	For Each Dimension In SetMetadata.Dimensions Do
		
		HasFilterByDimension = False;
		
		If TypeOf(FiltersToSet) = Type("ValueTable") Then
			HasFilterByDimension = FiltersToSet.Columns.Find(Dimension.Name) <> Undefined;
		Else //Filter
			HasFilterByDimension = FiltersToSet[Dimension.Name].Use;	
		EndIf;
		
		If Not HasFilterByDimension Then
			EmptyValue = Dimension.Type.AdjustValue();
			Set.Filter[Dimension.Name].Set(EmptyValue);
		EndIf;
	EndDo;
	
	If SetMetadata.MainFilterOnPeriod Then
		
		If TypeOf(FiltersToSet) = Type("ValueTable") Then
			HasFilterByDimension = FiltersToSet.Columns.Find("Period") <> Undefined;
		Else //Filter
			HasFilterByDimension = FiltersToSet.Period.Use;
		EndIf;
		
		If Not HasFilterByDimension Then
			EmptyValue = '00010101';
			Set.Filter.Period.Set(EmptyValue);
		EndIf;
		
	EndIf;
EndProcedure

Procedure RecordChanges(Parameters, Node, Data, DataKind, FullObjectName = "")
	
	ExchangePlans.RecordChanges(Node, Data);
	
	If Parameters.Property("HandlerData") Then
		If Not ValueIsFilled(FullObjectName) Then
			FullName = Data.Metadata().FullName();
		Else
			FullName = FullObjectName;
		EndIf;
		
		ObjectData = Parameters.HandlerData[FullName];
		If ObjectData = Undefined Then
			ObjectData = New Structure;
			ObjectData.Insert("Count", 1);
			ObjectData.Insert("PositionInQueue", Parameters.PositionInQueue);
			Parameters.HandlerData.Insert(FullName, ObjectData);
		Else
			Parameters.HandlerData[FullName].Count = ObjectData.Count + 1;
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange")
		AND StandardSubsystemsCached.DIBUsed("WithFilter")
		AND Not Parameters.ReRegistration
		AND Not Common.IsSubordinateDIBNode() Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.WriteUpdateDataToFile(Parameters, Data, DataKind, FullObjectName);
	EndIf;
	
EndProcedure

Function EarlierQueueNodes(PositionInQueue)
	Return ExchangePlans.InfobaseUpdate.EarlierQueueNodes(PositionInQueue);
EndFunction

Function QueueRef(PositionInQueue)
	Return ExchangePlans.InfobaseUpdate.NodeInQueue(PositionInQueue);
EndFunction

#EndRegion