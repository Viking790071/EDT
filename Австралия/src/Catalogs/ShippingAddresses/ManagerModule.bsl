#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Gets default shipping address.
//
// Parameters:
//  Counterparty - Ref to Owner of shipping addresses.
//
// Returns:
//  CatalogRef.ShippingAddresses - if there is shipping address marked as default or 
//  there is only one shipping address.
//  CatalogRef.Counterparties - if there are no delivery addresses.
//  Undefined - if there are several shipping addresses and no one is marked as default.
//
Function GetDefaultShippingAddress(Counterparty) Export
	
	Result = Undefined;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ShippingAddresses.Ref AS Ref,
	|	ShippingAddresses.IsDefault AS IsDefault
	|FROM
	|	Catalog.ShippingAddresses AS ShippingAddresses
	|WHERE
	|	ShippingAddresses.Owner = &Owner
	|	AND NOT ShippingAddresses.DeletionMark
	|
	|ORDER BY
	|	IsDefault DESC";
	
	Query.SetParameter("Owner", Counterparty);
	
	QueryResultTable = Query.Execute().Unload();
	If QueryResultTable.Count() > 0 Then
		
		If QueryResultTable.Count() = 1 Or QueryResultTable[0].IsDefault Then
			Result = QueryResultTable[0].Ref;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the list of attributes allowed to be changed
// with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	EditableAttributes.Add("ContactPerson");
	EditableAttributes.Add("Incoterms");
	EditableAttributes.Add("DeliveryTimeFrom");
	EditableAttributes.Add("DeliveryTimeTo");
	EditableAttributes.Add("SalesRep");
	
	Return EditableAttributes;
EndFunction

#Region LibrariesHandlers

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.ShippingAddresses);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Internal

#Region InfobaseUpdate

Function ConvertCounterpartiesToShippingAddresses() Export
	
	ConvertMap = New Map;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.ObsoleteShippingAddress AS ObsoleteShippingAddress,
	|	VALUETYPE(SalesInvoice.ObsoleteShippingAddress) = TYPE(Catalog.Counterparties) AS IsCounterparty
	|INTO DocumentsTable
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	(VALUETYPE(SalesInvoice.ObsoleteShippingAddress) = TYPE(Catalog.Counterparties)
	|				AND SalesInvoice.ObsoleteShippingAddress <> VALUE(Catalog.Counterparties.EmptyRef)
	|			OR VALUETYPE(SalesInvoice.ObsoleteShippingAddress) = TYPE(Catalog.ShippingAddresses)
	|				AND SalesInvoice.ObsoleteShippingAddress <> VALUE(Catalog.ShippingAddresses.EmptyRef))
	|	AND SalesInvoice.ShippingAddress = VALUE(Catalog.ShippingAddresses.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsIssue.Ref,
	|	GoodsIssue.ObsoleteShippingAddress,
	|	VALUETYPE(GoodsIssue.ObsoleteShippingAddress) = TYPE(Catalog.Counterparties)
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	(VALUETYPE(GoodsIssue.ObsoleteShippingAddress) = TYPE(Catalog.Counterparties)
	|				AND GoodsIssue.ObsoleteShippingAddress <> VALUE(Catalog.Counterparties.EmptyRef)
	|			OR VALUETYPE(GoodsIssue.ObsoleteShippingAddress) = TYPE(Catalog.ShippingAddresses)
	|				AND GoodsIssue.ObsoleteShippingAddress <> VALUE(Catalog.ShippingAddresses.EmptyRef))
	|	AND GoodsIssue.ShippingAddress = VALUE(Catalog.ShippingAddresses.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrder.Ref,
	|	SalesOrder.ObsoleteShippingAddress,
	|	VALUETYPE(SalesOrder.ObsoleteShippingAddress) = TYPE(Catalog.Counterparties)
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	(VALUETYPE(SalesOrder.ObsoleteShippingAddress) = TYPE(Catalog.Counterparties)
	|				AND SalesOrder.ObsoleteShippingAddress <> VALUE(Catalog.Counterparties.EmptyRef)
	|			OR VALUETYPE(SalesOrder.ObsoleteShippingAddress) = TYPE(Catalog.ShippingAddresses)
	|				AND SalesOrder.ObsoleteShippingAddress <> VALUE(Catalog.ShippingAddresses.EmptyRef))
	|	AND SalesOrder.ShippingAddress = VALUE(Catalog.ShippingAddresses.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	PurchaseOrder.Ref,
	|	PurchaseOrder.ObsoleteShippingAddress,
	|	VALUETYPE(PurchaseOrder.ObsoleteShippingAddress) = TYPE(Catalog.Counterparties)
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	(VALUETYPE(PurchaseOrder.ObsoleteShippingAddress) = TYPE(Catalog.Counterparties)
	|				AND PurchaseOrder.ObsoleteShippingAddress <> VALUE(Catalog.Counterparties.EmptyRef)
	|			OR VALUETYPE(PurchaseOrder.ObsoleteShippingAddress) = TYPE(Catalog.ShippingAddresses)
	|				AND PurchaseOrder.ObsoleteShippingAddress <> VALUE(Catalog.ShippingAddresses.EmptyRef))
	|	AND PurchaseOrder.ShippingAddress = VALUE(Catalog.ShippingAddresses.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	DocumentsTable.ObsoleteShippingAddress AS Counterparty
	|INTO CounterpartiesTable
	|FROM
	|	DocumentsTable AS DocumentsTable
	|WHERE
	|	DocumentsTable.IsCounterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsTable.Ref AS Ref,
	|	DocumentsTable.ObsoleteShippingAddress AS ObsoleteShippingAddress,
	|	DocumentsTable.IsCounterparty AS IsCounterparty
	|FROM
	|	DocumentsTable AS DocumentsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CounterpartiesContactInformation.Ref AS Counterparty,
	|	CounterpartiesContactInformation.Type AS Type,
	|	CounterpartiesContactInformation.Presentation AS Presentation,
	|	CounterpartiesContactInformation.FieldsValues AS FieldsValues,
	|	CounterpartiesContactInformation.Country AS Country,
	|	CounterpartiesContactInformation.State AS State,
	|	CounterpartiesContactInformation.City AS City,
	|	CounterpartiesContactInformation.EMAddress AS EMAddress,
	|	CounterpartiesContactInformation.ServerDomainName AS ServerDomainName,
	|	CounterpartiesContactInformation.PhoneNumber AS PhoneNumber,
	|	CounterpartiesContactInformation.PhoneNumberWithoutCodes AS PhoneNumberWithoutCodes,
	|	CounterpartiesContactInformation.KindForList AS KindForList,
	|	CounterpartiesContactInformation.Value AS Value
	|FROM
	|	Catalog.Counterparties.ContactInformation AS CounterpartiesContactInformation
	|		INNER JOIN CounterpartiesTable AS CounterpartiesTable
	|		ON CounterpartiesContactInformation.Ref = CounterpartiesTable.Counterparty
	|			AND (CounterpartiesContactInformation.Kind = VALUE(Catalog.ContactInformationKinds.CounterpartyLegalAddress))";
	
	ShippingAddressKind = Catalogs.ContactInformationKinds.ShippingAddress;
	
	Result = Query.ExecuteBatch();
	
	ContactInformation = Result[3].Unload();
	
	Selection = Result[2].Select();
	While Selection.Next() Do
		
		DocRef = Selection.Ref;
		DocObject = DocRef.GetObject();
		
		BeginTransaction();
		
		Try
			
			If Selection.IsCounterparty Then
				Counterparty = Selection.ObsoleteShippingAddress;
				ShippingAddress = ConvertMap.Get(Counterparty);
				
				If ShippingAddress = Undefined Then
					
					NewShippingAddress = Catalogs.ShippingAddresses.CreateItem();
					NewShippingAddress.Owner = Counterparty;
					NewShippingAddress.SalesRep = Common.ObjectAttributeValue(Counterparty, "SalesRep");
					
					ContactPerson = Catalogs.ContactPersons.GetDefaultContactPerson(Counterparty);
					If ValueIsFilled(ContactPerson) Then
						NewShippingAddress.ContactPerson = ContactPerson;
					EndIf;
					
					ContactInformationRow = ContactInformation.Find(Counterparty, "Counterparty");
					If ContactInformationRow = Undefined Then
						
						NewShippingAddress.Description = String(Counterparty);
						
					Else
						
						NewShippingAddress.Description = ContactInformationRow.Presentation;
						
						NewContactInformation = NewShippingAddress.ContactInformation.Add();
						FillPropertyValues(NewContactInformation, ContactInformationRow);
						NewContactInformation.Kind = ShippingAddressKind;
						
					EndIf;
					
					NewShippingAddress.Write();
					
					ConvertMap.Insert(Counterparty, NewShippingAddress.Ref);
					
				EndIf;
				
				DocObject.ShippingAddress = ConvertMap.Get(Counterparty);
				
				InfobaseUpdate.WriteObject(DocObject);
				
				If TypeOf(DocRef) = Type("DocumentRef.PurchaseOrder") Then
					DriveServer.InitializeAdditionalPropertiesForPosting(DocRef, DocObject.AdditionalProperties);
					
					AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(DocRef, DocObject.AdditionalProperties, False);
					If DocObject.AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
						
						RollbackTransaction();
						
						ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Cannot write document ""%1"".
								|The applicable Accounting transaction template is required.'; 
								|ru = 'Не удалось записать документ ""%1"".
								|Требуется соответствующий шаблон бухгалтерских операций.';
								|pl = 'Nie można zapisać dokumentu ""%1"".
								|Wymagany jest odpowiedni szablon transakcji księgowej.';
								|es_ES = 'No se ha podido guardar el documento ""%1"". 
								|Se requiere el modelo de transacción contable aplicable.';
								|es_CO = 'No se ha podido guardar el documento ""%1"". 
								|Se requiere el modelo de transacción contable aplicable.';
								|tr = '""%1"" belgesi kaydedilemiyor.
								|Uygulanabilir Muhasebe işlemi şablonu gerekli.';
								|it = 'Impossibile scrivere il documento ""%1"".
								|È necessario il modello di transazione contabile applicabile.';
								|de = 'Fehler beim Schreiben des Dokuments ""%1"". 
								|Die verwendbare Buchhaltungstransaktionsvorlage is erforderlich.'"),
							DocRef);
							
						WriteLogEvent(InfobaseUpdate.EventLogEvent(),
							EventLogLevel.Error,
							DocObject.Metadata(),
							,
							ErrorDescription);
							
						Continue;
						
					EndIf;
					
					Documents.PurchaseOrder.InitializeDocumentData(DocRef, DocObject.AdditionalProperties);
					DriveServer.ReflectOrdersByFulfillmentMethod(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
					InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.OrdersByFulfillmentMethod);
					DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
				EndIf;
				
			Else
				
				DocObject.ShippingAddress = Selection.ObsoleteShippingAddress;
				
				InfobaseUpdate.WriteObject(DocObject);
				
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot write document ""%1"". Details: %2'; ru = 'Не удается записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'No se ha podido guardar el documento ""%1"". Detalles: %2';es_CO = 'No se ha podido guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile scrivere il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				DocRef,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocObject.Metadata(),
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndFunction

#EndRegion

#EndRegion

#EndIf