#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetPredeterminedOverheadRate(Val Date = Undefined, Val Owner, Val CostDriver) Export
	
	StructureToReturn = New Structure;
	StructureToReturn.Insert("OverheadsGLAccount",	Undefined);
	StructureToReturn.Insert("Rate",				0);
		
	If NOT ValueIsFilled(Date) Then
		Date = CurrentSessionDate();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PredeterminedOverheadRatesSliceLast.OverheadsGLAccount AS OverheadsGLAccount,
	|	PredeterminedOverheadRatesSliceLast.Rate AS Rate
	|FROM
	|	InformationRegister.PredeterminedOverheadRates.SliceLast(
	|			&Date,
	|			Owner = &Owner
	|				AND CostDriver = &CostDriver) AS PredeterminedOverheadRatesSliceLast";
	Query.SetParameter("Date",			Date);
	Query.SetParameter("Owner",			Owner);
	Query.SetParameter("CostDriver",	CostDriver);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(StructureToReturn, Selection);
	Else
		CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Please specify Predetermined overhead rate actual on %1 for %2 and %3.'; ru = 'Укажите Предустановленную ставку накладных расходов на %1 для %2 и %3.';pl = 'Określ Przewidzianą rzeczywistą stawkę kosztów ogólnych rzeczywistą na %1 dla %2 i %3.';es_ES = 'Por favor, especifique la tasa de recargo predeterminada real %1para %2, %3.';es_CO = 'Por favor, especifique la tasa de recargo predeterminada real %1para %2, %3.';tr = 'Lütfen, %2 ve %3 için %1''de gerçek önceden belirlenmiş genel gider oranını belirtin.';it = 'Specificare i Costi orari generali predeterminati effettivi in %1 per %2 e %3.';de = 'Bitte geben Sie den vorgegebenen Ist-Gemeinkostenzuschlag gültig zum %1 für %2und %3 an.'"),
			Format(Date, "DLF=D"),
			Owner,
			CostDriver));
	EndIf;
	
	Return StructureToReturn;

EndFunction

Function GetActivityOverheadRate(Activity, Date, Company, BusinessUnit) Export
	
	Activities = New Array;
	Activities.Add(Activity);
	OverheadRates = GetActivitiesOverheadRates(Activities, Date, Company, BusinessUnit);
	Return OverheadRates.Total("Rate");
	
EndFunction

Function GetActivitiesOverheadRates(Activities, Date, Company, BusinessUnit) Export
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	ManufacturingActivities.Ref AS Activity,
	|	ManufacturingActivities.CostPool AS CostPool
	|INTO TT_Activities
	|FROM
	|	Catalog.ManufacturingActivities AS ManufacturingActivities
	|WHERE
	|	ManufacturingActivities.Ref IN (&Activities)";
	
	DriveClientServer.AddDelimeter(Query.Text);
	Query.Text = Query.Text + GetActivitiesOverheadRatesQueryText();
	
	DriveClientServer.AddDelimeter(Query.Text);
	Query.Text = Query.Text +
	"SELECT
	|	TT_ActivitiesOverheadRates.Activity AS Activity,
	|	TT_ActivitiesOverheadRates.OverheadsGLAccount AS OverheadsGLAccount,
	|	TT_ActivitiesOverheadRates.BusinessUnit AS BusinessUnit,
	|	TT_ActivitiesOverheadRates.Rate AS Rate
	|FROM
	|	TT_ActivitiesOverheadRates AS TT_ActivitiesOverheadRates";
	
	Query.SetParameter("Activities",	Activities);
	Query.SetParameter("Date",			Date);
	Query.SetParameter("Company",		Company);
	Query.SetParameter("BusinessUnit",	BusinessUnit);
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetActivitiesOverheadRatesQueryText() Export
	
	Return
	"SELECT
	|	TT_Activities.Activity AS Activity,
	|	TT_Activities.CostPool AS CostPool,
	|	CostPools.CostDriver AS CostDriver,
	|	AccountingPolicy.ManufacturingOverheadsAllocationMethod AS OverheadsMethod
	|INTO TT_ActivitiesParameters
	|FROM
	|	TT_Activities AS TT_Activities
	|		LEFT JOIN Catalog.CostPools AS CostPools
	|		ON TT_Activities.CostPool = CostPools.Ref,
	|	InformationRegister.AccountingPolicy.SliceLast(&Date, Company = &Company) AS AccountingPolicy
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OverheadRates.Owner AS Owner,
	|	OverheadRates.CostDriver AS CostDriver,
	|	OverheadRates.ExpenseItem AS ExpenseItem,
	|	OverheadRates.OverheadsGLAccount AS OverheadsGLAccount,
	|	OverheadRates.BusinessUnit AS BusinessUnit,
	|	OverheadRates.Rate AS Rate
	|INTO TT_OverheadRates
	|FROM
	|	InformationRegister.PredeterminedOverheadRates.SliceLast(&Date, Company = &Company) AS OverheadRates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ActivitiesParameters.Activity AS Activity,
	|	TT_OverheadRates.ExpenseItem AS ExpenseItem,
	|	TT_OverheadRates.OverheadsGLAccount AS OverheadsGLAccount,
	|	TT_OverheadRates.BusinessUnit AS BusinessUnit,
	|	TT_OverheadRates.Rate AS Rate
	|INTO TT_ActivitiesOverheadRatesAllBusinessUnits
	|FROM
	|	TT_ActivitiesParameters AS TT_ActivitiesParameters
	|		INNER JOIN TT_OverheadRates AS TT_OverheadRates
	|		ON TT_ActivitiesParameters.CostDriver = TT_OverheadRates.CostDriver
	|WHERE
	|	TT_ActivitiesParameters.OverheadsMethod = VALUE(Enum.ManufacturingOverheadsAllocationMethods.PlantwideAllocation)
	|	AND TT_OverheadRates.Owner = &Company
	|	AND (TT_OverheadRates.BusinessUnit = &BusinessUnit
	|			OR TT_OverheadRates.BusinessUnit = VALUE(Catalog.BusinessUnits.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	TT_ActivitiesParameters.Activity,
	|	TT_OverheadRates.ExpenseItem,
	|	TT_OverheadRates.OverheadsGLAccount,
	|	TT_OverheadRates.BusinessUnit,
	|	TT_OverheadRates.Rate
	|FROM
	|	TT_ActivitiesParameters AS TT_ActivitiesParameters
	|		INNER JOIN TT_OverheadRates AS TT_OverheadRates
	|		ON TT_ActivitiesParameters.CostDriver = TT_OverheadRates.CostDriver
	|WHERE
	|	TT_ActivitiesParameters.OverheadsMethod = VALUE(Enum.ManufacturingOverheadsAllocationMethods.DepartmentalAllocation)
	|	AND TT_OverheadRates.Owner = &BusinessUnit
	|	AND (TT_OverheadRates.BusinessUnit = &BusinessUnit
	|			OR TT_OverheadRates.BusinessUnit = VALUE(Catalog.BusinessUnits.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	TT_ActivitiesParameters.Activity,
	|	TT_OverheadRates.ExpenseItem,
	|	TT_OverheadRates.OverheadsGLAccount,
	|	TT_OverheadRates.BusinessUnit,
	|	TT_OverheadRates.Rate
	|FROM
	|	TT_ActivitiesParameters AS TT_ActivitiesParameters
	|		INNER JOIN TT_OverheadRates AS TT_OverheadRates
	|		ON TT_ActivitiesParameters.CostPool = TT_OverheadRates.Owner
	|			AND TT_ActivitiesParameters.CostDriver = TT_OverheadRates.CostDriver
	|WHERE
	|	TT_ActivitiesParameters.OverheadsMethod = VALUE(Enum.ManufacturingOverheadsAllocationMethods.ActivityBasedCosting)
	|	AND (TT_OverheadRates.BusinessUnit = &BusinessUnit
	|			OR TT_OverheadRates.BusinessUnit = VALUE(Catalog.BusinessUnits.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.Activity AS Activity,
	|	MAX(TT_ActivitiesOverheadRatesAllBusinessUnits.BusinessUnit) AS BusinessUnit
	|INTO TT_ActivitiesBusinessUnit
	|FROM
	|	TT_ActivitiesOverheadRatesAllBusinessUnits AS TT_ActivitiesOverheadRatesAllBusinessUnits
	|
	|GROUP BY
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.Activity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.Activity AS Activity,
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.ExpenseItem AS ExpenseItem,
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.OverheadsGLAccount AS OverheadsGLAccount,
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.BusinessUnit AS BusinessUnit,
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.Rate AS Rate
	|INTO TT_ActivitiesOverheadRates
	|FROM
	|	TT_ActivitiesOverheadRatesAllBusinessUnits AS TT_ActivitiesOverheadRatesAllBusinessUnits
	|		INNER JOIN TT_ActivitiesBusinessUnit AS TT_ActivitiesBusinessUnit
	|		ON TT_ActivitiesOverheadRatesAllBusinessUnits.Activity = TT_ActivitiesBusinessUnit.Activity
	|			AND TT_ActivitiesOverheadRatesAllBusinessUnits.BusinessUnit = TT_ActivitiesBusinessUnit.BusinessUnit
	|
	|GROUP BY
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.Activity,
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.ExpenseItem,
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.OverheadsGLAccount,
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.BusinessUnit,
	|	TT_ActivitiesOverheadRatesAllBusinessUnits.Rate";
	
EndFunction

#EndRegion

#EndIf