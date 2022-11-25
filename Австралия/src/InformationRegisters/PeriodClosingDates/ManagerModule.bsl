
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	    VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
	|	OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
	|	OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
	|	OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
	|	OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf
