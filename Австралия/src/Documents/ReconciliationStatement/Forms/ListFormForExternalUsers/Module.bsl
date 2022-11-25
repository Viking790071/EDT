
#Region FormEventHandlers

&AtServer
Procedure FormManagment()
	Items.BusinessProcessJobCreateBasedOn.Visible = GetFunctionalOption("UseSupportForExternalUsers");
EndProcedure

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
Procedure StatusFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Status", Status, ValueIsFilled(Status));
	
EndProcedure

&AtClient
Procedure CompanyFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	GeneratePrintFormReconciliationStatement();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenDocument(Command)
	
	GeneratePrintFormReconciliationStatement();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GeneratePrintFormReconciliationStatement()
	
	If Items.List.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RefsArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		RefsArray.Add(Row);	
	EndDo;
	
	OpenParameters = New Structure("PrintManagerName, TemplatesNames, CommandParameter, PrintParameters");
	OpenParameters.PrintManagerName = "Document.ReconciliationStatement";
	OpenParameters.TemplatesNames   = "ReconciliationStatement";
	OpenParameters.CommandParameter	 = RefsArray;
	
	PrintParameters = New Structure("FormTitle, ID, AdditionalParameters");
	PrintParameters.FormTitle = NStr("en = 'Reconciliation statement'; ru = 'Сверка взаиморасчетов';pl = 'Uzgodnienie';es_ES = 'Declaración de reconciliación';es_CO = 'Declaración de reconciliación';tr = 'Mutabakat ekstresi';it = 'Dichiarazione di riconciliazione';de = 'Saldenabgleich'");
	PrintParameters.ID = "ReconciliationStatement";
	PrintParameters.AdditionalParameters = New Structure("Result");
	OpenParameters.PrintParameters = PrintParameters;
	
	If Not PrintManagementClientDrive.DisplayPrintOption(RefsArray, OpenParameters, FormOwner, UniqueKey, OpenParameters.PrintParameters) Then
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisObject, UniqueKey);
	EndIf;
	
EndProcedure

#EndRegion

