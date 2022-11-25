
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisObject, ExternalUsers.ExternalUserAuthorizationData());
	CommonClientServer.SetDynamicListParameter(List, "Counterparty", AuthorizedCounterparty);
	CommonClientServer.SetDynamicListParameter(List, "UseContractRestrictionsTurnOff",
		Not GetFunctionalOption("UseContractRestrictionsForExternalUsers"));
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagment();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CompanyFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	GeneratePrintFormQuotation();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenDocument(Command)
	
	GeneratePrintFormQuotation();
	
EndProcedure

&AtClient
Procedure Copy(Command)
	
	If Items.List.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RefsArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		RefsArray.Add(Row);
	EndDo;
	
	Notify("Document.Quote.CopyTS", RefsArray);
	OpenForm("DataProcessor.ProductCartForExternalUsers.Form", New Structure("BasisRefsArray, Quotation", RefsArray, RefsArray[0]));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FormManagment()
	
	CommonClientServer.SetFormItemProperty(Items,
		"BusinessProcessJobCreateBasedOn",
		"Visible",
		GetFunctionalOption("UseSupportForExternalUsers"));
	
EndProcedure

&AtClient
Procedure GeneratePrintFormQuotation()
	
	If Items.List.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RefsArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		RefsArray.Add(Row);
	EndDo;
	
	PrintManagementClientDrive.GeneratePrintFormForExternalUsers(RefsArray,
		"Document.Quote",
		"Quote",
		NStr("en = 'Quote'; ru = 'Коммерческое предложение';pl = 'Oferta cenowa';es_ES = 'Presupuesto';es_CO = 'Presupuesto';tr = 'Teklif';it = 'Preventivo';de = 'Angebot'"),
		FormOwner,
		UniqueKey);
	
EndProcedure

#EndRegion