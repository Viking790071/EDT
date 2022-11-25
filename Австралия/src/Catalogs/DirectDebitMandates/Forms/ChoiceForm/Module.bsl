#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetFilterAndConditionalAppearance();
		
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

#EndRegion

#Region Private

// Sets the filter and conditional list appearance if a counterparty has the billing details by contracts.
//
&AtServer
Procedure SetFilterAndConditionalAppearance()
	
	If Not (Parameters.FilterActiveMandatesOnly) Then
		Return;
	EndIf;
	
	FilterItemCompany = List.Filter.Items.Add(type("DataCompositionFilterItem"));
	FilterItemCompany.LeftValue = New DataCompositionField("Company");
	FilterItemCompany.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItemCompany.Use = True;
	FilterItemCompany.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	FilterItemCompany.RightValue = Parameters.FilterCompany;
	
	FilterItemStatus = List.Filter.Items.Add(type("DataCompositionFilterItem"));
	FilterItemStatus.LeftValue = New DataCompositionField("MandateStatus");
	FilterItemStatus.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItemStatus.Use = True;
	FilterItemStatus.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	FilterItemStatus.RightValue = Enums.CounterpartyContractStatuses.Closed;
	
	FilterItemStatusGroup1 = List.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
    FilterItemStatusGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
	FilterItemFromDate1 = FilterItemStatusGroup1.Items.Add(type("DataCompositionFilterItem"));
	FilterItemFromDate1.LeftValue = New DataCompositionField("MandatePeriodFrom");
	FilterItemFromDate1.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	FilterItemFromDate1.Use = True;
	FilterItemFromDate1.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	FilterItemFromDate1.RightValue = Parameters.FilterMandateActiveDate;
	
	FilterItemFromDate2 = FilterItemStatusGroup1.Items.Add(type("DataCompositionFilterItem"));
	FilterItemFromDate2.LeftValue = New DataCompositionField("MandatePeriodFrom");
	FilterItemFromDate2.ComparisonType = DataCompositionComparisonType.NotFilled;
	FilterItemFromDate2.Use = True;
	FilterItemFromDate2.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	

	FilterItemStatusGroup2 = List.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
    FilterItemStatusGroup2.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	FilterItemToDate1 = FilterItemStatusGroup2.Items.Add(type("DataCompositionFilterItem"));
	FilterItemToDate1.LeftValue = New DataCompositionField("MandatePeriodTo");
	FilterItemToDate1.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
	FilterItemToDate1.Use = True;
	FilterItemToDate1.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	FilterItemToDate1.RightValue = Parameters.FilterMandateActiveDate;
	
	FilterItemToDate2 = FilterItemStatusGroup2.Items.Add(type("DataCompositionFilterItem"));
	FilterItemToDate2.LeftValue = New DataCompositionField("MandatePeriodTo");
	FilterItemToDate2.ComparisonType = DataCompositionComparisonType.NotFilled;
	FilterItemToDate2.Use = True;
	FilterItemToDate2.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
EndProcedure

#EndRegion

