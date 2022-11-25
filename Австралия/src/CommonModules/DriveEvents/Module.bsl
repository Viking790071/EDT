
#Region SubscriptionToEvents

// Predefines a standard presentation of a reference.
//
Procedure GetDocumentFieldsPresentation(Source, Fields, StandardProcessing) Export
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("Posted");
	Fields.Add("DeletionMark");
	If TypeOf(Source) = Type("DocumentManager.SalesInvoice") Then
		Fields.Add("OperationKind");
	ElsIf TypeOf(Source) = Type("DocumentManager.AccountingTransaction") Then
		Fields.Add("IsManual");
	EndIf;
	
EndProcedure

// Predefines a standard presentation of a reference.
//
Procedure GetDocumentFieldsPresentationWriteOnly(Source, Fields, StandardProcessing) Export
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("DeletionMark");
	
EndProcedure

// Predefines a standard presentation of a reference.
//
Procedure GetDocumentPresentation(Source, Data, Presentation, StandardProcessing) Export
	
	If Data.Number = Null
		OR Not ValueIsFilled(Data.Ref) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	Status = "";
	Try
		If Data.DeletionMark Then
			Status = NStr("en = '(deleted)'; ru = '(удален)';pl = '(usunięty)';es_ES = '(borrado)';es_CO = '(borrado)';tr = '(silindi)';it = '(eliminato)';de = '(gelöscht)'");
		ElsIf Data.Property("Posted") AND Not Data.Posted Then
			Status = NStr("en = '(not posted)'; ru = '(не проведен)';pl = '(niezatwierdzony)';es_ES = '(no enviado)';es_CO = '(no enviado)';tr = '(onaylanmadı)';it = '(Non pubblicato)';de = '(nicht gebucht)'");
		EndIf;
	Except
		WriteLogEvent(NStr("en = 'Get document presentation'; ru = 'Получить представление документа';pl = 'Pobierz prezentację dokumentu';es_ES = 'Recibir la presentación del documento';es_CO = 'Recibir la presentación del documento';tr = 'Belge sunumu al';it = 'Ottenere presentazione documento';de = 'Dokumentpräsentation erhalten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,String(Data.Ref));
		Return;
	EndTry;
	
	If Not Data.Property("Number") Then
		NumberPresentation = "";
	Else
		NumberPresentation = TrimAll(Data.Number);
	EndIf;
	
	If TypeOf(Data.Ref) = Type("DocumentRef.SalesInvoice")
		And Data.OperationKind = Enums.OperationTypesSalesInvoice.ClosingInvoice Then
		MetadataPresentation = NStr("en = 'Closing invoice'; ru = 'Заключительный инвойс';pl = 'Faktura końcowa';es_ES = 'Factura de cierre';es_CO = 'Factura de cierre';tr = 'Kapanış faturası';it = 'Fattura di saldo';de = 'Abschlussrechnung'");
	ElsIf TypeOf(Data.Ref) = Type("DocumentRef.AccountingTransaction") Then
		If Data.IsManual Then
			MetadataPresentation = Documents.AccountingTransaction.GetTitleManual();
		Else
			MetadataPresentation = Documents.AccountingTransaction.GetTitleDefault();
		EndIf;
	Else
		DocumentMetadata = Data.Ref.Metadata();
		MetadataPresentation = DocumentMetadata.ExtendedObjectPresentation;
		If IsBlankString(MetadataPresentation) Then
			MetadataPresentation = DocumentMetadata.ObjectPresentation;
		EndIf;
		If IsBlankString(MetadataPresentation) Then
			MetadataPresentation = DocumentMetadata.Presentation();
		EndIf;
	EndIf;
	
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 %2 dated %3 %4'; ru = '%1 %2 от %3 %4';pl = '%1 %2 z dn. %3 %4';es_ES = '%1 %2 fechado %3 %4';es_CO = '%1 %2 fechado %3 %4';tr = '%1 %2 tarihli %3 %4';it = '%1 %2 con data %3 %4';de = '%1 %2 datiert %3 %4'"),
		MetadataPresentation,
		NumberPresentation,
		Format(Data.Date, "DLF=D"),
		Status);
	
EndProcedure

#EndRegion
