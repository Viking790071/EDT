#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Imports data from the exchange message file.
//
// Parameters:
//  Cancel - Boolean - a cancel flag appears on errors during exchange message processing.
// 
Procedure RunDataImport(Cancel, Val ImportOnlyParameters) Export
	
	If Not IsDistributedInfobaseNode() Then
		
		// The exchange must follow the conversion rules.
		AddExchangeFinishEventLogMessage(Cancel,, DataExchangeKindError());
		Return;
	EndIf;
	
	ImportMetadata = ImportOnlyParameters
		AND DataExchangeServer.IsSubordinateDIBNode()
		AND (DataExchangeServerCall.RetryDataExchangeMessageImportBeforeStart()
			OR NOT DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
					"MessageReceivedFromCache"));
					
	DataAnalysisResultToExport = DataExchangeServer.DataAnalysisResultToExport(ExchangeMessageFileName(), False, True);
	ExchangeMessageFileSize = DataAnalysisResultToExport.ExchangeMessageFileSize;
	ObjectsToImportCount = DataAnalysisResultToExport.ObjectsToImportCount;
	
	// Setting session parameters.
	DataSynchronizationSessionParameters = New Map;
	SetPrivilegedMode(True);
	Try
		CurrentSessionParameter = SessionParameters.DataSynchronizationSessionParameters.Get();
	Except
		CurrentSessionParameter = Undefined;
	EndTry;
	
	If TypeOf(CurrentSessionParameter) = Type("Map") Then
		For Each Item In CurrentSessionParameter Do
			DataSynchronizationSessionParameters.Insert(Item.Key, Item.Value);
		EndDo;
	EndIf;
	
	DataSynchronizationSessionParameters.Insert(InfobaseNode, 
						New Structure("ExchangeMessageFileSize, ObjectsToImportCount",
						ExchangeMessageFileSize, ObjectsToImportCount));
	SessionParameters.DataSynchronizationSessionParameters = New ValueStorage(DataSynchronizationSessionParameters);
	SetPrivilegedMode(False);
	
	
	XMLReader = New XMLReader;
	
	Try
		XMLReader.OpenFile(ExchangeMessageFileName());
	Except
		
		// Error opening the exchange message file.
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorOpeningExchangeMessageFile());
		Return;
	EndTry;
	
	DataExchangeInternal.DisableAccessKeysUpdate(True);
	ReadExchangeMessageFile(Cancel, XMLReader, ImportOnlyParameters, ImportMetadata);
	DataExchangeInternal.DisableAccessKeysUpdate(False);
	
	XMLReader.Close();
EndProcedure

// Exports data to the exchange message file.
//
// Parameters:
//  Cancel - Boolean - a cancel flag appears on errors during exchange message processing.
//  ErrorMessage Parameters - String - Textual description of the data export error.
// 
Procedure RunDataExport(Cancel, ErrorMessage = "") Export
	
	If Not IsDistributedInfobaseNode() Then
		// The exchange must follow the conversion rules.
		ErrorMessage = DataExchangeKindError();
		AddExchangeFinishEventLogMessage(Cancel, , ErrorMessage);
		Return;
	EndIf;
	
	XMLWriter = New XMLWriter;
	
	Try
		XMLWriter.OpenFile(ExchangeMessageFileName());
	Except
		// Error opening the exchange message file.
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		AddExchangeFinishEventLogMessage(Cancel, ErrorMessage, ErrorOpeningExchangeMessageFile());
		Return;
	EndTry;
	
	WriteChangesToExchangeMessageFile(Cancel, XMLWriter, ErrorMessage);
	
	XMLWriter.Close();
	
EndProcedure

// Passes the string with the full exchange message file name for data import or export to the 
// ExchangeMessageFileNameField local variable.
// Usually, the exchange message file places in the operating system user temporary directory.
// 
//
// Parameters:
//  FileName - String - full exchange message file name for data export or import.
// 
Procedure SetExchangeMessageFileName(Val FileName) Export
	
	ExchangeMessageFileNameField = FileName;
	
EndProcedure

//

Procedure ReadExchangeMessageFile(Cancel, XMLReader, Val ImportOnlyParameters, Val ImportMetadata)
	
	MessageReader = ExchangePlans.CreateMessageReader();
	
	Try
		MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	Except
		// Unknown exchange plan is specified.
		// The exchange plan does not contain the specified node.
		// message number does not match the expected one.
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorStartRedingTheExchangeMessageFile());
		Return;
	EndTry;
	
	CommonDataNode = Undefined;
	ReceivedMessageNumber = MessageReader.ReceivedNo;
	ExchangeNode = MessageReader.Sender;
	
	If ImportOnlyParameters Then
		
		If ImportMetadata Then
			
			Try
				
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationParameters", True);
				SetPrivilegedMode(False);
				
				// Receiving configuration changes, ignoring data changes
				ExchangePlans.ReadChanges(MessageReader, TransactionItemsCount);
				
				// Reading priority data (predefined items, metadata object IDs).
				ReadPriorityChangesFromExchangeMessage(MessageReader, CommonDataNode);
				
				// Pretending the message is still not received. Interrupting the data reading.
				MessageReader.CancelRead();
				
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationParameters", False);
				SetPrivilegedMode(False);
			Except
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationParameters", False);
				SetPrivilegedMode(False);
				
				MessageReader.CancelRead();
				AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorReadingExchangeMessageFile());
				Return;
			EndTry;
			
		Else
			
			Try
				
				// Skipping configuration changes and data changes in the exchange message.
				MessageReader.XMLReader.Skip(); // <Changes>...</Changes>
				
				MessageReader.XMLReader.Read(); // </Changes>
				
				// Reading priority data (predefined items, metadata object IDs).
				ReadPriorityChangesFromExchangeMessage(MessageReader, CommonDataNode);
				
				// Pretending the message is still not received. Interrupting the data reading.
				MessageReader.CancelRead();
			Except
				MessageReader.CancelRead();
				AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorReadingExchangeMessageFile());
				Return
			EndTry;
			
		EndIf;
		
	Else
		
		Try
			
			// Receiving configuration changes and data changes from the exchange message.
			ExchangePlans.ReadChanges(MessageReader, TransactionItemsCount);
			
			// Reading priority data (predefined items, metadata object IDs).
			ReadPriorityChangesFromExchangeMessage(MessageReader, CommonDataNode);
			
			// The message is considered received
			MessageReader.EndRead();
		Except
			MessageReader.CancelRead();
			AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorReadingExchangeMessageFile());
			Return
		EndTry;
		
	EndIf;
	
	// Common data of nodes is written after the message is read.
	If CommonDataNode <> Undefined Then
		
		CommonNodeData = DataExchangeCached.CommonNodeData(ExchangePlans.MasterNode());
		CurrentNode = ExchangePlans.MasterNode().GetObject();
		If DataExchangeEvents.DataDifferent(CurrentNode, CommonDataNode, CommonNodeData) Then
			DataExchangeEvents.FillObjectPropertyValues(CurrentNode, CommonDataNode, CommonNodeData);
			CurrentNode.Write();
		EndIf;
		
	EndIf;
	
	InformationRegisters.CommonNodeDataChanges.DeleteChangeRecords(ExchangeNode, ReceivedMessageNumber);
	
EndProcedure

Procedure WriteChangesToExchangeMessageFile(Cancel, XMLWriter, ErrorMessage = "")
	
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	Try
		WriteMessage.BeginWrite(XMLWriter, InfobaseNode);
	Except
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		AddExchangeFinishEventLogMessage(Cancel, ErrorMessage, ErrorStartWritingTheExchangeMessageFile());
		Return;
	EndTry;
	
	// Setting session parameters.
	ObjectsToExportCount = DataExchangeServer.CalculateRegisteredObjectsCount(InfobaseNode);
	DataSynchronizationSessionParameters = New Map;
	SetPrivilegedMode(True);
	Try
		CurrentSessionParameter = SessionParameters.DataSynchronizationSessionParameters.Get();
	Except
		CurrentSessionParameter = Undefined;
	EndTry;
	
	If TypeOf(CurrentSessionParameter) = Type("Map") Then
		For Each Item In CurrentSessionParameter Do
			DataSynchronizationSessionParameters.Insert(Item.Key, Item.Value);
		EndDo;
	EndIf;
	
	DataSynchronizationSessionParameters.Insert(InfobaseNode, 
						New Structure("ObjectsToExportCount",
						ObjectsToExportCount));
	SessionParameters.DataSynchronizationSessionParameters = New ValueStorage(DataSynchronizationSessionParameters);
	SetPrivilegedMode(False);
	
	Try
		
		DataExchangeServerCall.ClearPriorityExchangeData();
		
		// Writing configuration changes and data changes to the exchange message.
		ExchangePlans.WriteChanges(WriteMessage, TransactionItemsCount);
		
		// Recording first-priority data to the end of the exchange message (predefined items, metadata 
		// object IDs).
		WritePriorityChangesToExchangeMessage(WriteMessage);
		
		WriteMessage.EndWrite();
	Except
		WriteMessage.CancelWrite();
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		AddExchangeFinishEventLogMessage(Cancel, ErrorMessage, ErrorSavingExchangeMessageFile());
		Return;
	EndTry;
	
EndProcedure

// Writes priority data (such as metadata object IDs) to the exchange message.
// For example, predefined items and metadata object IDs.
//
Procedure WritePriorityChangesToExchangeMessage(Val WriteMessage)
	
	// Writing the <Parameters> element
	WriteMessage.XMLWriter.WriteStartElement("Parameters");
	
	If WriteMessage.Recipient <> ExchangePlans.MasterNode() Then
		
		// Exporting priority exchange data (predefined items.
		PriorityExchangeData = DataExchangeServerCall.PriorityExchangeData();
		
		If PriorityExchangeData.Count() > 0 Then
			
			ChangesSelection = DataExchangeServer.SelectChanges(
				WriteMessage.Recipient,
				WriteMessage.MessageNo,
				PriorityExchangeData);
			
			BeginTransaction();
			Try
				
				While ChangesSelection.Next() Do
					
					WriteXML(WriteMessage.XMLWriter, ChangesSelection.Get());
					
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		EndIf;
		
		If Not StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
			
			// Exporting the metadata object IDs catalog.
			ChangesSelection = DataExchangeServer.SelectChanges(
				WriteMessage.Recipient,
				WriteMessage.MessageNo,
				Metadata.Catalogs["MetadataObjectIDs"]);
			
			BeginTransaction();
			Try
				
				While ChangesSelection.Next() Do
					
					WriteXML(WriteMessage.XMLWriter, ChangesSelection.Get());
					
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		EndIf;
		
		// Exporting common data of nodes.
		NodeChangesSelection = InformationRegisters.CommonNodeDataChanges.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
		
		If NodeChangesSelection.Count() <> 0 Then
			
			CommonNodeData = DataExchangeCached.CommonNodeData(WriteMessage.Recipient);
			
			If Not IsBlankString(CommonNodeData) Then
				
				ExchangePlanName = DataExchangeCached.GetExchangePlanName(WriteMessage.Recipient);
				CommonNode = ExchangePlans[ExchangePlanName].CreateNode();
				DataExchangeEvents.FillObjectPropertyValues(CommonNode, WriteMessage.Recipient.GetObject(), CommonNodeData);
				WriteXML(WriteMessage.XMLWriter, CommonNode);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	WriteMessage.XMLWriter.WriteEndElement(); // Parameters
	
EndProcedure

// Reading first-priority data from the exchange message (predefined items, metadata object IDs).
// 
//
Procedure ReadPriorityChangesFromExchangeMessage(Val MessageReader, CommonDataNode)
	
	If MessageReader.Sender = ExchangePlans.MasterNode() Then
		
		MessageReader.XMLReader.Read(); // <Parameters>
		
		BeginTransaction();
		Try
			
			DuplicatesOfPredefinedItems = "";
			Cancel = False;
			CancelDetails = "";
			IDObjects = New Array;
			ExchangePlanName = DataExchangeCached.GetExchangePlanName(MessageReader.Sender);
			TypeExchangePlanObject = Type("ExchangePlanObject." + ExchangePlanName);
			
			If NotUniqueRecordsFound("Catalog.MetadataObjectIDs") Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NotUniqueRecordErrorTemplate(),
					NStr("ru = '?????????? ?????????????????? ?????????????????????????????? ???????????????? ????????????????????
					           |?? ?????????????????????? ?????????????? ???? ???????????????????? ????????????.'; 
					           |en = 'Non-unique entries were found in the catalog
					           |before importing IDs of metadata objects.'; 
					           |pl = 'Przed eksportem identyfikator??w obiekt??w
					           |metadanych znaleziono nieunikalne zapisy w katalogu.';
					           |es_ES = 'Antes de exportar los
					           |identificadores de objetos de metadatos se han encontrado las grabaciones no ??nicas en el cat??logo.';
					           |es_CO = 'Antes de exportar los
					           |identificadores de objetos de metadatos se han encontrado las grabaciones no ??nicas en el cat??logo.';
					           |tr = 'Meta veri nesne tan??mlay??c??lar??n?? y??klemeden ??nce, dizinde 
					           |benzersiz olmayan kay??tlar bulundu.';
					           |it = 'Sono state trovate registrazioni non univoche nel catalogo
					           |prima dell''importazione di ID di oggetti metadati.';
					           |de = 'Vor dem Export der
					           |Metadatenobjekt-IDs wurden im Katalog nicht eindeutige Datens??tze gefunden.'"));
			EndIf;
			
			While CanReadXML(MessageReader.XMLReader) Do
				
				Data = ReadXML(MessageReader.XMLReader);
				
				Data.DataExchange.Load = True;
				
				If TypeOf(Data) = TypeExchangePlanObject Then // Node common data
					
					CommonDataNode = Data;
					Continue;
					
				EndIf;
				
				Data.DataExchange.Sender = MessageReader.Sender;
				Data.DataExchange.Recipients.AutoFill = False;
				
				If TypeOf(Data) = Type("CatalogObject.MetadataObjectIDs") Then
					IDObjects.Add(Data);
					Continue;
					
				ElsIf TypeOf(Data) <> Type("ObjectDeletion") Then // This is a predefined item
					
					If Not Data.Predefined Then
						Continue; // Only predefined items are processed
					EndIf;
					
				Else // Type("ObjectDeletion")
					
					// 1. ID references are deleted independently in each node using deletion marks and marked object 
					//    deletion.
					// 2. Deletion of predefined items is not exported.
					Continue;
				EndIf;
				
				WritePredefinedDataRef(Data);
				AddPredefinedItemDuplicateDetails(Data, DuplicatesOfPredefinedItems, Cancel, CancelDetails);
			EndDo;
			
			If Cancel Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '???????????????? ???????????????????????? ???????????? ???? ??????????????????.
					           |?????? ???????????????? ???????????????????????????????? ?????????????????? ?????????????? ???? ???????????????????? ????????????.
					           |???? ?????????????????? ???????????????? ?????????????????????? ????????????????????.
					           |%1'; 
					           |en = 'Priority data import failed.
					           |While importing predefined items, non-unique entries were found.
					           |Cannot continue because of the following reasons.
					           |%1'; 
					           |pl = '??adowanie danych o priorytecie nie powiod??o si??.
					           |Podczas ??adowania wst??pnie zdefiniowanych pozycji znaleziono nieunikalne zapisy.
					           |Z nast??puj??cych powod??w kontynuacja nie jest mo??liwa.
					           |%1';
					           |es_ES = 'La descarga de los datos prioritarias no se ha ejecutado.
					           |Al descargar los elementos predeterminados no se han encontrado registros no ??nicos.
					           |Por las siguientes causas es imposible continuar.
					           |%1';
					           |es_CO = 'La descarga de los datos prioritarias no se ha ejecutado.
					           |Al descargar los elementos predeterminados no se han encontrado registros no ??nicos.
					           |Por las siguientes causas es imposible continuar.
					           |%1';
					           |tr = '??ncelikli veriler y??klenemedi. 
					           |??nceden tan??mlanm???? ????eleri y??klerken hi??bir benzersiz kay??tlar?? bulundu.
					           |A??a????daki nedenlerden dolay?? devam etmek imkans??zd??r.
					           |%1';
					           |it = 'Importazione dati prioritari non riuscita.
					           |Sono state trovate registrazioni non univoche durante l''importazione di elementi predefiniti.
					           |Impossibile continuare per i seguenti motivi.
					           |%1';
					           |de = 'Priorit??tsdaten wurden nicht heruntergeladen.
					           |Beim Import vordefinierter Elemente wurden keine eindeutigen Datens??tze gefunden.
					           |Aus den folgenden Gr??nden ist es unm??glich, fortzufahren.
					           |%1'"),
					CancelDetails);
			EndIf;
			
			If ValueIsFilled(DuplicatesOfPredefinedItems) Then
				WriteLogEvent(
					NStr("ru = '???????????????????????????????? ????????????????.?????????????? ???? ???????????????????? ????????????.'; en = 'Predefined items.Duplicate records are found.'; pl = 'Elementy predefiniowane.Znaleziono elementy nieunikalne.';es_ES = 'Art??culos predefinidos.Entradas no ??nicas encontradas.';es_CO = 'Art??culos predefinidos.Entradas no ??nicas encontradas.';tr = '??nceden tan??mlanm???? ????eler. Benzersiz olmayan kay??tlar bulundu.';it = 'Elementi predefiniti. Trovati record duplicati.';de = 'Vordefinierte Elemente. Nicht eindeutige Eintr??ge gefunden.'",
						CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = '?????? ???????????????? ???????????????????????????????? ?????????????????? ?????????????? ???? ???????????????????? ????????????.
						           |%1'; 
						           |en = 'When importing predefined items, non-unique records were found.
						           |%1'; 
						           |pl = 'W czasie importu wst??pnie zdefiniowanych element??w znaleziono nieunikalne zapisy.
						           |%1';
						           |es_ES = 'Al importar los art??culos predefinidos, se han encontrado las grabaciones no ??nicas.
						           |%1';
						           |es_CO = 'Al importar los art??culos predefinidos, se han encontrado las grabaciones no ??nicas.
						           |%1';
						           |tr = '??ntan??ml?? ????eler i??e aktar??l??rken benzersiz olmayan kay??tlar bulundu. 
						           |%1';
						           |it = 'Trovati record duplicati durante l''importazione di elementi predefiniti.
						           |%1';
						           |de = 'Beim Importieren vordefinierter Elemente wurden nicht eindeutige Datens??tze gefunden.
						           |%1'"),
						DuplicatesOfPredefinedItems));
			EndIf;
			
			UpdatePredefinedItemsDeletion();
			
			If Not StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
				Catalogs.MetadataObjectIDs.ImportDataToSubordinateNode(IDObjects);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		MessageReader.XMLReader.Read(); // </Parameters>
		
	Else
		
		// Skipping the application execution parameters.
		MessageReader.XMLReader.Skip(); // <Parameters>...</Parameters>
		
		MessageReader.XMLReader.Read(); // </Parameters>
		
	EndIf;
	
EndProcedure

Procedure AddExchangeFinishEventLogMessage(Cancel, ErrorDescription = "", ContextErrorDescription = "")
	
	Cancel = True;
	
	Comment = "[ContextErrorDescription]: [ErrorDescription]"; // Do not localize.
	
	Comment = StrReplace(Comment, "[ContextErrorDescription]", ContextErrorDescription);
	Comment = StrReplace(Comment, "[ErrorDescription]", ErrorDescription);
	
	WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
		InfobaseNode.Metadata(), InfobaseNode, Comment);
	
EndProcedure

Function IsDistributedInfobaseNode()
	
	Return DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode);
	
EndFunction

Procedure WritePredefinedDataRef(Data)
	
	ObjectMetadata = Metadata.FindByType(TypeOf(Data.Ref));
	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	ObjectManager = Common.ObjectManagerByRef(Data.Ref);
	
	If Data.IsNew() Then
		If Common.IsCatalog(ObjectMetadata) Then
			If ObjectMetadata.Hierarchical
				AND ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems
				AND Data.IsFolder Then
				Object = ObjectManager.CreateFolder();
			Else
				Object = ObjectManager.CreateItem();
			EndIf;
		ElsIf Common.IsChartOfCharacteristicTypes(ObjectMetadata) Then
			If ObjectMetadata.Hierarchical
				AND Data.IsFolder Then
				Object = ObjectManager.CreateFolder();
			Else
				Object = ObjectManager.CreateItem();
			EndIf;
		ElsIf Common.IsChartOfAccounts(ObjectMetadata) Then
			Object = ObjectManager.CreateAccount();
		ElsIf Common.IsChartOfCalculationTypes(ObjectMetadata) Then
			Object = ObjectManager.CreateCalculationType();
		EndIf;
	Else
		Object = Data.Ref.GetObject();
	EndIf;
	
	If Data.IsNew() Then
		Object.SetNewObjectRef(Data.GetNewObjectRef());
		Object.PredefinedDataName = Data.PredefinedDataName;
		Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
		Object.AdditionalProperties.Insert("PriorityDataImport");
		InfobaseUpdate.WriteData(Object);
		
	ElsIf Object.PredefinedDataName <> Data.PredefinedDataName Then
		Object.PredefinedDataName = Data.PredefinedDataName;
		Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
		Object.AdditionalProperties.Insert("PriorityDataImport");
		InfobaseUpdate.WriteData(Object);
	Else
		// If the predefined item exists, preliminary import is not required
	EndIf;
	
	Data = Object;
	
EndProcedure

Procedure AddPredefinedItemDuplicateDetails(WrittenObject, DuplicatesOfPredefinedItems, Cancel, CancelDetails)
	
	ObjectMetadata = Metadata.FindByType(TypeOf(WrittenObject.Ref));
	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	Table = ObjectMetadata.FullName();
	PredefinedDataName = WrittenObject.PredefinedDataName;
	Ref = WrittenObject.Ref;
	
	Query = New Query;
	Query.SetParameter("PredefinedDataName", PredefinedDataName);
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.PredefinedDataName = &PredefinedDataName";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
	Selection = Query.Execute().Select();
	
	DuplicateRefIDs = "";
	DuplicateCount = 0;
	FoundRefs = New Map;
	RefToImportFound = False;
	
	While Selection.Next() Do
		// Searching for duplicate records that are relevant to predefined items
		If FoundRefs.Get(Selection.Ref) = Undefined Then
			FoundRefs.Insert(Selection.Ref, 1);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NotUniqueRecordErrorTemplate(),
				NStr("ru = '?????? ???????????????? ???????????????????????????????? ?????????????????? ?????????????? ???? ???????????????????? ????????????.'; en = 'Duplicate records are found during the predefined item import.'; pl = 'W czasie importu wst??pnie zdefiniowanych element??w znaleziono nieunikalne zapisy.';es_ES = 'Al importar los art??culos predefinidos, se han encontrado las grabaciones no ??nicas.';es_CO = 'Al importar los art??culos predefinidos, se han encontrado las grabaciones no ??nicas.';tr = '??nceden tan??mlanm???? ????eler y??klenirken benzersiz olmayan kay??tlar bulundu.';it = 'Record duplicati trovati durante l''importazione di elementi predefiniti.';de = 'Beim Importieren vordefinierter Elemente wurden nicht eindeutige Datens??tze gefunden.'"));
		EndIf;
		// Searching for duplicate predefined items
		If Ref = Selection.Ref AND Not RefToImportFound Then
			RefToImportFound = True;
			Continue;
		EndIf;
		DuplicateCount = DuplicateCount + 1;
		If ValueIsFilled(DuplicateRefIDs) Then
			DuplicateRefIDs = DuplicateRefIDs + ",";
		EndIf;
		DuplicateRefIDs = DuplicateRefIDs
			+ String(Selection.Ref.UUID());
	EndDo;
	
	If DuplicateCount = 0 Then
		Return;
	EndIf;
	
	WriteToLog = True;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		
		Details = "";
		ModuleAccessManagementInternal.OnFindNotUniquePredefinedItem(
			WrittenObject, WriteToLog, Cancel, Details);
		
		If ValueIsFilled(Details) Then
			CancelDetails = CancelDetails + Chars.LF + TrimAll(Details) + Chars.LF;
		EndIf;
	EndIf;
	
	If WriteToLog Then
		If DuplicateCount = 1 Then
			Template = NStr("ru = '(?????????????????????? ????????????: %1, ???????????? ??????????: %2)'; en = '(import reference: %1, duplicate reference: %2)'; pl = '(zaimportowany link: %1, powielony link: %2)';es_ES = '(referencia importada: %1, referencia de duplicado: %2)';es_CO = '(referencia importada: %1, referencia de duplicado: %2)';tr = '(y??klenen referans: %1, kopya referans??: %2)';it = '(riferimento importazione: %1, riferimento duplicato: %2)';de = '(importierte Referenz: %1, doppelte Referenz: %2)'");
		Else
			Template = NStr("ru = '(?????????????????????? ????????????: %1, ???????????? ????????????: %2)'; en = '(import references: %1, duplicate references: %2)'; pl = '(zaimportowany link: %1, powielony link %2)';es_ES = '(referencia importada: %1, referencias de duplicado %2)';es_CO = '(referencia importada: %1, referencias de duplicado %2)';tr = '(y??klenen referans: %1, kopyalar??n referans??: %2)';it = '(riferimenti importazione: %1, riferimenti duplicato: %2)';de = '(importierte Referenz: %1, doppelte Referenzen: %2)'");
		EndIf;
		DuplicatesOfPredefinedItems = DuplicatesOfPredefinedItems + Chars.LF
			+ Table + "." + PredefinedDataName + Chars.LF
			+ StringFunctionsClientServer.SubstituteParametersToString(
				Template,
				String(Ref.UUID()),
				DuplicateRefIDs)
			+ Chars.LF;
	EndIf;
	
EndProcedure

Function NotUniqueRecordsFound(Table)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|
	|GROUP BY
	|	MetadataObjectIDs.Ref
	|
	|HAVING
	|	COUNT(MetadataObjectIDs.Ref) > 1";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function NotUniqueRecordErrorTemplate()
	Return
		NStr("ru = '???????????????? ???????????????????????? ???????????? ???? ??????????????????.
		           |%1
		           |?????????????????? ?????????????????????? ???????????????????????????? ????????.
		           |1. ???????????????? ????????????????????????, ?????????????????? ?? ???????? ??????????????????????????????????,
		           |   ???????????????? ?????????? ""???????????????????????? ?? ?????????????????????? ..."".
		           |2. ?? ?????????????????????? ??????????
		           |   - ???????????????? ???????????? ?????????? ""???????????????? ???????????????????? ?????????????????????? ???????????????????????????? ????????"";
		           |   - ???????????????? ?????????????? ""???????????????????????? ?? ??????????????????????"", ?? ???? ""???????????? ????????????????????????"";
		           |   - ?????????????? ??????????????????.
		           |3. ?????????? ?????????? ?????????????????? 1??:?????????????????????? ?? ?????????????????? ?????????????????? ?????????????????????????? ????????????.'; 
		           |en = 'Priority data import failed.
		           |%1
		           |The infobase requires correction.
		           |1. Open Designer, go to the Administration menu,
		           |   click ""Testing and correction ..."".
		           |2. In the opened form
		           |   ??? select only ""Check for logical integrity of infobase"";
		           |   - select ""Testing and correction"" rather than ""Testing only"";
		           |   - click Run.
		           |3. Then run 1C:Enterprise and resynchronize the data.'; 
		           |pl = '??adowanie danych priorytetowych nie jest zako??czone.
		           |%1
		           |Wymagana jest korekta bazy danych.
		           |1. Otw??rz konfigurator, przejd?? do menu Administracja,
		           | wybierz element ""Testowanie i naprawa..."".
		           |2. W formularzu, kt??ry si?? otworzy
		           | - uwzgl??dnij tylko pozycj?? ""Sprawdzanie logicznej integralno??ci bazy danych"";
		           | - wybierz opcj?? ""Testowanie i utrwalanie"", a nie ""Tylko testowanie"";
		           | - kliknij Wykonaj.
		           |3. Nast??pnie uruchom 1C: Enterprise i ponownie zsynchronizuj dane.??';
		           |es_ES = 'La descarga de los cambios importantes no se ha finalizado.
		           |%1
		           |Se requiere corregir la base de informaci??n.
		           |1. Abrir el configurador, ir al men?? Administraci??n,
		           | seleccionar el apartado ""Pruebas y correcci??n..."".
		           |2. En el formulario abierto
		           | - activar solo el apartado ""Revisar solo la integridad l??gica de la infobase"";
		           | - seleccionar la variante ""Pruebas y correcci??n"" y no ""Solo pruebas"";
		           | - hacer clic en Ejecutar.
		           |3. Despu??s, lanzar 1C:Enterprise y volver a sincronizar los datos.';
		           |es_CO = 'La descarga de los cambios importantes no se ha finalizado.
		           |%1
		           |Se requiere corregir la base de informaci??n.
		           |1. Abrir el configurador, ir al men?? Administraci??n,
		           | seleccionar el apartado ""Pruebas y correcci??n..."".
		           |2. En el formulario abierto
		           | - activar solo el apartado ""Revisar solo la integridad l??gica de la infobase"";
		           | - seleccionar la variante ""Pruebas y correcci??n"" y no ""Solo pruebas"";
		           | - hacer clic en Ejecutar.
		           |3. Despu??s, lanzar 1C:Enterprise y volver a sincronizar los datos.';
		           |tr = '??ncelikli veriler y??klenemedi. 
		           |%1
		           |Bir bilgi taban?? d??zeltmesi gereklidir.
		           |1. Yap??land??r??c??y?? a????n, Y??netim men??s??ne gidin, 
		           |""Test Et ve d??zelt"" maddesini se??in ...""
		           |2. A????lan formda
		           |-sadece ""Veritaban??n??n mant??ksal b??t??nl??????n?? kontrol et"" se??ene??ini etkinle??tirin; 
		           |- ""Yaln??zca test"" yerine ""Test ve d??zeltme"" se??ene??ini se??in; 
		           |- ??al????t??r''?? t??klay??n.
		           |3. Bundan sonra 1C:????letme''yi ??al????t??r??n ve verileri yeniden senkronize edin.';
		           |it = 'Importazione dati prioritari non riuscita.
		           |%1
		           |L''infobase necessita di correzione.
		           |1. Apri Designer, vai al menu Amministrazione,
		           | clicca ""Test e correzione ..."".
		           |2. Nel modulo che si apre
		           | - seleziona solo ""Controllo dell''integrit?? logica dell''infobase"";
		           | - seleziona ""Test e correzione"" invece del ""Solo test"";
		           | - clicca Esegui.
		           |3. Poi avvia 1C:Enterprise e risincronizza dati.';
		           |de = 'Priorit??tsdaten wurden nicht heruntergeladen.
		           |%1
		           |Eine Korrektur der Informationsbasis ist erforderlich.
		           |1. ??ffnen Sie den Designer, gehen Sie in das Men?? Administration,
		           |w??hlen Sie ""Testen und Korrigieren"".
		           |2. Schalten Sie in der angezeigten Form
		           |nur den Punkt ""Logische Integrit??t der Informationsbasis pr??fen"" ein;
		           |   - W??hlen Sie die Option ""Testen und Korrigieren"", nicht ""Nur Testen"";
		           |   - Klicken Sie auf Ausf??hren.
		           |3. Danach starten Sie 1C:Enterprise und synchronisieren die Daten erneut.'");
EndFunction

Procedure UpdatePredefinedItemsDeletion()
	
	SetPrivilegedMode(True);
	
	MetadataCollections = New Array;
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	For each Collection In MetadataCollections Do
		For Each MetadataObject In Collection Do
			If MetadataObject = Metadata.Catalogs.MetadataObjectIDs Then
				Continue; // Metadata objects of this type are updated in the procedure that updates metadata object IDs
			EndIf;
			UpdatePredefinedItemDeletion(MetadataObject.FullName());
		EndDo;
	EndDo;
	
EndProcedure

Procedure UpdatePredefinedItemDeletion(Table)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Predefined = TRUE";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If StrStartsWith(Selection.PredefinedDataName, "#") Then
			
			Object = Selection.Ref.GetObject();
			Object.PredefinedDataName = "";
			Object.DeletionMark = True;
			
			Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
			InfobaseUpdate.WriteData(Object);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal functions for retrieving properties.

Function ExchangeMessageFileName()
	
	If Not ValueIsFilled(ExchangeMessageFileNameField) Then
		
		ExchangeMessageFileNameField = "";
		
	EndIf;
	
	Return ExchangeMessageFileNameField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Description of errors of execution context.

Function ErrorOpeningExchangeMessageFile()
	
	Return NStr("ru = '???????????? ???????????????? ?????????? ?????????????????? ????????????'; en = 'An error occurred when opening the exchange message file'; pl = 'B????d otwarcia pliku wiadomo??ci wymiany';es_ES = 'Ha ocurrido un error al abrir el archivo de mensajes de intercambio';es_CO = 'Ha ocurrido un error al abrir el archivo de mensajes de intercambio';tr = 'De??i??im mesaj dosyas?? a????l??rken bir hata olu??tu';it = 'Si ?? verificato un errore durante l''apertura del file messaggio di scambio';de = 'Beim ??ffnen der Austausch-Nachrichtendatei ist ein Fehler aufgetreten'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function ErrorStartRedingTheExchangeMessageFile()
	
	Return NStr("ru = '???????????? ?????? ???????????? ???????????? ?????????? ?????????????????? ????????????'; en = 'Error at the beginning of reading the exchange message file'; pl = 'B????d podczas rozpocz??cia odczytu pliku wiadomo??ci wymiany';es_ES = 'Ha ocurrido un error al iniciar la lectura del archivo de mensajes de intercambio';es_CO = 'Ha ocurrido un error al iniciar la lectura del archivo de mensajes de intercambio';tr = 'Veri al????veri??i mesaj?? dosyas??n?? okumaya ba??larken bir hata olu??tu';it = 'Errore all''inizio della lettura del file di messaggio di scambio';de = 'Beim Lesen der Austausch-Nachrichtendatei ist ein Fehler aufgetreten'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function ErrorStartWritingTheExchangeMessageFile()
	
	Return NStr("ru = '???????????? ?????? ???????????? ???????????? ?????????? ?????????????????? ????????????'; en = 'Error at the beginning of writing the exchange message file'; pl = 'Wyst??pi?? podczas rozpocz??cia odczytu pliku wiadomo??ci wymiany';es_ES = 'Ha ocurrido un error al iniciar a grabar el archivo de mensajes de intercambio';es_CO = 'Ha ocurrido un error al iniciar a grabar el archivo de mensajes de intercambio';tr = 'Veri al????veri??i mesaj?? dosyas??n?? kaydetmeye ba??larken bir hata olu??tu';it = 'Errore all''inizio della scrittura del file di messaggio di scambio';de = 'Beim Schreiben der Austausch-Nachrichtendatei ist ein Fehler aufgetreten'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function ErrorReadingExchangeMessageFile()
	
	Return NStr("ru = '???????????? ???????????? ?????????? ?????????????????? ????????????'; en = 'Error reading the exchange message file.'; pl = 'B????d odczytu pliku wiadomo??ci wymiany';es_ES = 'Ha ocurrido un error al leer el archivo de mensajes de intercambio';es_CO = 'Ha ocurrido un error al leer el archivo de mensajes de intercambio';tr = 'Veri al????veri??i mesaj?? dosyas?? okunurken bir hata olu??tu';it = 'Errore di lettura del file di messaggio di scambio.';de = 'Beim Lesen einer Austausch-Nachrichtendatei ist ein Fehler aufgetreten'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function ErrorSavingExchangeMessageFile()
	
	Return NStr("ru = '???????????? ???????????? ???????????? ?? ???????? ?????????????????? ????????????'; en = 'Error saving the exchange message file.'; pl = 'B????d zapisu danych do pliku wiadomo??ci wymiany';es_ES = 'Ha ocurrido un error al grabar los datos en el archivo de mensajes de intercambio';es_CO = 'Ha ocurrido un error al grabar los datos en el archivo de mensajes de intercambio';tr = 'Veriler al????veri?? mesaj?? dosyas??na kaydedilirken bir hata olu??tu';it = 'Errore durante il salvataggio del file di messaggio di scambio.';de = 'Beim Schreiben einer Austausch-Nachrichtendatei ist ein Fehler aufgetreten'");
	
EndFunction

Function DataExchangeKindError()
	
	Return NStr("ru = '?????????? ???? ???? ???????????????? ?????????????????????? ???? ????????????????????????????'; en = 'Exchange not according to conversion rules is not supported'; pl = 'Wymiana niezgodna z regu??ami konwersji nie jest obs??ugiwana';es_ES = 'Intercambio no seg??n las reglas de conversi??n no se admite';es_CO = 'Intercambio no seg??n las reglas de conversi??n no se admite';tr = 'D??n??????m kurallar??na uygun olmayan de??i??im desteklenmiyor';it = 'Lo scambio non regolato dalle regole di conversione non ?? supportato';de = 'Austausch nicht gem???? den Konvertierungsregeln wird nicht unterst??tzt'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

#EndRegion

#EndIf
