#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification data processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Type;Type");
	AttributesToLock.Add("Parent");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region InfobaseUpdate

// Registers other contact information kinds, for which the FieldKindOther field is to be filled in, for processing.
//
Procedure FillContactInformationKindsWithOtherFieldToProcess(Parameters) Export
	
	Query = New Query;
	Query.Text = "SELECT
		|	ContactInformationKinds.Ref,
		|	ContactInformationKinds.DeleteMultilineFIeld
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	ContactInformationKinds.Type = &Type";
	
	Query.SetParameter("Type", Enums.ContactInformationTypes.Other);
	QueryResult = Query.Execute().Unload();

	InfobaseUpdate.MarkForProcessing(Parameters,
		QueryResult.UnloadColumn("Ref"));
	
EndProcedure

Procedure FillContactInformationKinds(Parameters) Export
	
	ContactInformationKindRef = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, "Catalog.ContactInformationKinds");
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	While ContactInformationKindRef.Next() Do
		Try
			ContactInformationKind = ContactInformationKindRef.Ref.GetObject();
			If ContactInformationKind.DeleteMultilineFIeld Then
				ContactInformationKind.FieldKindOther = "MultilineWide";
			Else
				ContactInformationKind.FieldKindOther = "SingleLineWide";
			EndIf;
			InfobaseUpdate.WriteData(ContactInformationKind);
			ObjectsProcessed = ObjectsProcessed + 1;
			
		Except
			// If you cannot process any kind of contact information, try again.
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось обработать вид контактной информации: %1 по причине: %2'; en = 'Cannot process contact information kind: %1 due to: %2'; pl = 'Nie udało się przetworzyć rodzaju informacji kontaktowej: %1 z powodu: %2';es_ES = 'No se ha podido el tipo de la información de contacto: %1 a causa de: %2';es_CO = 'No se ha podido el tipo de la información de contacto: %1 a causa de: %2';tr = 'İletişim bilgilerin türü işlenemedi: %1 nedeni: %2';it = 'Impossibile elaborare la tipologia di informazioni di contatto: %1 a causa di: %2';de = 'Die Art der Kontaktinformationen konnte nicht verarbeitet werden: %1 aus diesem Grund: %2'"),
					ContactInformationKindRef.Ref, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.Catalogs.ContactInformationKinds, ContactInformationKindRef.Ref, MessageText);
		EndTry;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "Catalog.ContactInformationKinds");
	
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедуре FillContactInformationKinds не удалось обработать некоторые виды контактной информации (пропущены): %1'; en = 'The FillContactInformationKinds procedure cannot process some contact information kinds (skipped): %1.'; pl = 'Procedurze FillContactInformationKinds nie udało się przetworzyć niektórych rodzajów informacji kontaktowej (pominięte): %1';es_ES = 'El procedimiento FillContactInformationKinds no puede procesar algunos tipos de información de contacto (omitido):%1';es_CO = 'El procedimiento FillContactInformationKinds no puede procesar algunos tipos de información de contacto (omitido):%1';tr = 'FillContactInformationKinds prosedürü bazı iletişim bilgisi türlerini işleyemedi (atlandı): %1.';it = 'La procedura FillContactInformationKinds non può elaborare alcuni tipi di informazione di contatto (saltati): %1.';de = 'Die Prozedur FillContactInformationKinds konnte einige Arten von Kontaktinformationen nicht verarbeiten (weggelassen): %1.'"), 
				ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.ContactInformationKinds,,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Процедура FillContactInformationKinds обработала очередную порцию видов контактной информации: %1'; en = 'The FillContactInformationKinds procedure has processed contact information kinds: %1.'; pl = 'Procedura FillContactInformationKinds przetworzyła kolejną porcję informacji kontaktowej: %1';es_ES = 'El procedimiento FillContactInformationKinds ha procesado tipos de información de contacto: %1';es_CO = 'El procedimiento FillContactInformationKinds ha procesado tipos de información de contacto: %1';tr = 'FillContactInformationKinds prosedürü iletişim bilgisi türlerini işledi: %1.';it = 'La procedura FillContactInformationKinds ha elaborato i tipi di informazione di contatto: %1.';de = 'Die Prozedur FillContactInformationKinds hat eine weitere Reihe von Kontaktinformationsarten verarbeitet: %1.'"),
					ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion


#EndIf