#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetVisibility();
	Numbering.FillDocumentsTypesList(Items.DocumentType.ChoiceList);
	SetOperationTypeType();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not ValueIsFilled(CurrentObject.OperationType) Then
		CurrentObject.OperationType = Undefined;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetOperationTypeType();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NumeratorOnChange(Item)
	
	SetVisibility();
	
EndProcedure

&AtClient
Procedure DocumentTypeOnChange(Item)
	
	SetOperationTypeType();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetVisibility()
	
	If ValueIsFilled(Record.Numerator) Then
		
		NumeratorData = Numbering.GetNumeratorAttributes(Record.Numerator);
		
		Items.NumberingPeriod.Visible =
			(NumeratorData.Periodicity <> Enums.NumeratorsPeriodicity.Nonperiodical);
		
		Items.DocumentType.Visible	= NumeratorData.IndependentNumberingByDocumentTypes;
		Items.OperationType.Visible	= NumeratorData.IndependentNumberingByOperationTypes;
		Items.Company.Visible		= NumeratorData.IndependentNumberingByCompanies;
		Items.BusinessUnit.Visible	= NumeratorData.IndependentNumberingByBusinessUnits;
		Items.Counterparty.Visible	= NumeratorData.IndependentNumberingByCounterparties;
		
	Else
		
		Items.NumberingPeriod.Visible = False;
		Items.DocumentType.Visible	= False;
		Items.OperationType.Visible	= False;
		Items.Company.Visible		= False;
		Items.BusinessUnit.Visible	= False;
		Items.Counterparty.Visible	= False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetOperationTypeType()
	
	If ValueIsFilled(Record.DocumentType) Then
	
		OperationTypeTypeDescription = Numbering.GetOperationTypeTypeDescription(Record.DocumentType);
		
		If OperationTypeTypeDescription = Undefined Then
			Record.OperationType = Undefined;
		Else
			Record.OperationType = OperationTypeTypeDescription.AdjustValue(Record.OperationType);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion