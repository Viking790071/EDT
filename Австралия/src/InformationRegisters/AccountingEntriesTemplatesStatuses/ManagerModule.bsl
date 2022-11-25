
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure SaveStatusHistory(ElemRef, Status, StartDate, EndDate) Export

	SetPrivilegedMode(True);
	
	CurrentData = Common.ObjectAttributesValues(ElemRef, "Status, StartDate, EndDate");
	
	If CurrentData.Status <> Status 
		Or CurrentData.StartDate <> StartDate
		Or CurrentData.EndDate <> EndDate Then

		RegSet = InformationRegisters.AccountingEntriesTemplatesStatuses.CreateRecordSet();
		RegSet.Filter.Period.Set(CurrentSessionDate());
		RegSet.Filter.Template.Set(ElemRef);
		
		RegEntry = RegSet.Add();
		RegEntry.Template	= ElemRef;
		RegEntry.Period		= CurrentSessionDate();
		RegEntry.Status		= Status;
		RegEntry.StartDate	= StartDate;
		RegEntry.EndDate 	= EndDate;
		RegEntry.User 		= SessionParameters.CurrentUser;
		
		RegSet.Write(True);
		
	EndIf;
	
EndProcedure

Function GetTemplatesArrayByFilters(FilterDate, FilterStatus)  Export

	Query = New Query;
	
	Query.SetParameter("FilterStatus" , FilterStatus);
	Query.SetParameter("ParameterDate", FilterDate);
	
	Query.Text =
	"SELECT
	|	AccountingEntriesTemplatesStatusesSliceLast.Template AS Template
	|FROM
	|	InformationRegister.AccountingEntriesTemplatesStatuses.SliceLast(, ) AS AccountingEntriesTemplatesStatusesSliceLast
	|WHERE
	|	&FilterStatus = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingEntriesTemplatesStatusesSliceLast.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingEntriesTemplatesStatusesSliceLast.StartDate <= &ParameterDate
	|	AND CASE
	|			WHEN AccountingEntriesTemplatesStatusesSliceLast.EndDate <> DATETIME(1, 1, 1)
	|				THEN AccountingEntriesTemplatesStatusesSliceLast.EndDate >= &ParameterDate
	|			ELSE TRUE
	|		END
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesStatusesSliceLast.Template
	|FROM
	|	InformationRegister.AccountingEntriesTemplatesStatuses.SliceLast(, ) AS AccountingEntriesTemplatesStatusesSliceLast
	|WHERE
	|	&FilterStatus = VALUE(Enum.AccountingEntriesTemplatesStatuses.Draft)
	|	AND CASE
	|			WHEN AccountingEntriesTemplatesStatusesSliceLast.StartDate <> DATETIME(1, 1, 1)
	|				THEN AccountingEntriesTemplatesStatusesSliceLast.StartDate > &ParameterDate
	|			ELSE TRUE
	|		END
	|	AND CASE
	|			WHEN AccountingEntriesTemplatesStatusesSliceLast.EndDate <> DATETIME(1, 1, 1)
	|				THEN AccountingEntriesTemplatesStatusesSliceLast.EndDate >= &ParameterDate
	|			ELSE TRUE
	|		END";
	
	Result = Query.Execute();
	Return Result.Unload().UnloadColumn("Template");

EndFunction 

#EndRegion

#EndIf
