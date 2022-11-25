#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure, Import = False) Export
	
	AttributesToCheck = New Array;
	AttributesToCheck.Add("InfobaseNode");
	AttributesToCheck.Add("DestinationUID");
	
	For Each AttributeToCheck In AttributesToCheck Do
		If RecordStructure.Property(AttributeToCheck)
			AND Not ValueIsFilled(RecordStructure[AttributeToCheck]) Then
			
			EventDescription = NStr("ru = 'Добавление записи регистра сведений ""Соответствия объектов информационных баз""'; en = 'Add record to information register ""Mapping of infobase objects""'; pl = 'Dodanie wpisu rejestru informacyjnego ""Zgodność obiektów baz informacyjnych""';es_ES = 'Añadir el registro del registro de información ""Correspondencias de objetos de las bases de información""';es_CO = 'Añadir el registro del registro de información ""Correspondencias de objetos de las bases de información""';tr = 'Bilgi kaydedici kaydını ""Veritabanı nesnelerin uyumluluğu"" ekleme';it = 'Aggiungere record al registro informazioni ""Mappatura di oggetti infobase""';de = 'Hinzufügen eines Informationsregistereintrags ""Mapping von Infobaseobjekten""'",
				CommonClientServer.DefaultLanguageCode());
			Comment     = NStr("ru = 'Не заполнен реквизит %1. Создание записи регистра невозможно.'; en = 'Attribute %1 is not entered. Cannot create the register record.'; pl = 'Niezapełnione atrybuty %1. Utworzenie wpisu rejestru nie jest możliwe.';es_ES = 'Requisito %1 no rellenado. Imposible crear el registro del registro.';es_CO = 'Requisito %1 no rellenado. Imposible crear el registro del registro.';tr = 'Özellik %1doldurulmadı. Kaydedicinin kaydının oluşturulması imkansızdır.';it = 'Il requisito %1 non è inserito. Impossibile creare la registrazione.';de = 'Nicht ausgefüllte Requisiten %1. Das Erstellen eines Registereintrags ist nicht möglich.'");
			Comment     = StringFunctionsClientServer.SubstituteParametersToString(Comment, AttributeToCheck);
			WriteLogEvent(EventDescription, 
			                         EventLogLevel.Error,
			                         Metadata.InformationRegisters.InfobaseObjectsMaps,
			                         ,
			                         Comment);
			
			Return;
			
		EndIf;
	EndDo;
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "InfobaseObjectsMaps", Import);
	
EndProcedure

// Deletes a register record based on the passed structure values.
Procedure DeleteRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "InfobaseObjectsMaps", Import);
	
EndProcedure

Function ObjectIsInRegister(Object, InfobaseNode) Export
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
	|WHERE
	|	  InfobaseObjectsMaps.InfobaseNode           = &InfobaseNode
	|	AND InfobaseObjectsMaps.SourceUUID = &SourceUUID
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode",           InfobaseNode);
	Query.SetParameter("SourceUUID", Object);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Procedure DeleteObsoleteExportByRefModeRecords(InfobaseNode) Export
	
	QueryText = "
	|////////////////////////////////////////////////////////// {InfobaseObjectsMapsByRef}
	|SELECT
	|	InfobaseObjectsMaps.InfobaseNode,
	|	InfobaseObjectsMaps.SourceUUID,
	|	InfobaseObjectsMaps.DestinationUID,
	|	InfobaseObjectsMaps.DestinationType,
	|	InfobaseObjectsMaps.SourceType
	|INTO InfobaseObjectsMapsByRef
	|FROM
	|	InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
	|WHERE
	|	  InfobaseObjectsMaps.InfobaseNode = &InfobaseNode
	|	AND InfobaseObjectsMaps.ObjectExportedByRef
	|;
	|
	|//////////////////////////////////////////////////////////{}
	|SELECT DISTINCT
	|	InfobaseObjectsMapsByRef.InfobaseNode,
	|	InfobaseObjectsMapsByRef.SourceUUID,
	|	InfobaseObjectsMapsByRef.DestinationUID,
	|	InfobaseObjectsMapsByRef.DestinationType,
	|	InfobaseObjectsMapsByRef.SourceType
	|FROM
	|	InfobaseObjectsMapsByRef AS InfobaseObjectsMapsByRef
	|LEFT JOIN InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
	|ON   InfobaseObjectsMaps.SourceUUID = InfobaseObjectsMapsByRef.SourceUUID
	|	AND InfobaseObjectsMaps.ObjectExportedByRef = FALSE
	|	AND InfobaseObjectsMaps.InfobaseNode = &InfobaseNode
	|WHERE
	|	NOT InfobaseObjectsMaps.InfobaseNode IS NULL
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			RecordStructure = New Structure("InfobaseNode, SourceUUID, DestinationUID, DestinationType, SourceType");
			
			FillPropertyValues(RecordStructure, Selection);
			
			DeleteRecord(RecordStructure, True);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure AddObjectToAllowedObjectsFilter(Val Object, Val Recipient) Export
	
	If Not ObjectIsInRegister(Object, Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("SourceUUID", Object);
		RecordStructure.Insert("ObjectExportedByRef", True);
		
		AddRecord(RecordStructure, True);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf