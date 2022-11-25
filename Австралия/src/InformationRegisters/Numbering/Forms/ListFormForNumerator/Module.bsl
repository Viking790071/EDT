#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonClientServer.SetFilterItem(List.Filter, "Numerator", Parameters.Numerator);
	
	If ValueIsFilled(Parameters.Numerator) Then
		
		NumeratorData = Numbering.GetNumeratorAttributes(Parameters.Numerator);
		
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

#EndRegion