#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Collects catalog data by metadata object references and updates register data.
//
Procedure UpdateDataByMetadataObjectReferences(MetadataObjectReferences) Export
	Query = NewRegisterDataUpdateQuery(MetadataObjectReferences);
	
	ReferencesSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While ReferencesSelection.Next() Do
		RecordSelection = ReferencesSelection.Select();
		While RecordSelection.Next() Do
			RecordManager = CreateRecordManager();
			FillPropertyValues(RecordManager, RecordSelection);
			RecordManager.Write(True);
		EndDo;
		
		// Registering the references being used for further deleting the unused ones from the register.
		MetadataObjectReferences.Delete(MetadataObjectReferences.Find(ReferencesSelection.RelatedObject));
	EndDo;
	
	// Clearing register from unused references.
	For Each RelatedObject In MetadataObjectReferences Do
		RecordSet = CreateRecordSet();
		RecordSet.Filter.RelatedObject.Set(RelatedObject);
		RecordSet.Write(True);
	EndDo;
EndProcedure

// Overwriting all register data.
//
Procedure Refresh(IBUpdateMode = False) Export
	
	Query = NewRegisterDataUpdateQuery(Undefined);
	ReferencesSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	RecordSet = CreateRecordSet();
	While ReferencesSelection.Next() Do
		RecordSelection = ReferencesSelection.Select();
		While RecordSelection.Next() Do
			FillPropertyValues(RecordSet.Add(), RecordSelection);
		EndDo;
	EndDo;
	
	If IBUpdateMode Then
		InfobaseUpdate.WriteData(RecordSet);
	Else
		RecordSet.Write();
	EndIf;
	
EndProcedure

// Returns the text of registry data update query.
//
Function NewRegisterDataUpdateQuery(MetadataObjectReferences)
	
	Query = New Query;
	
	QueryText =
	"SELECT DISTINCT
	|	AdditionalReportsAndDataProcessorsAssignment.RelatedObject AS RelatedObject,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsAssignment.Ref.Kind = &KindObjectFilling
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseObjectFilling,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsAssignment.Ref.Kind = &ReportKind
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseReports,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsAssignment.Ref.Kind = &KindCreateRelatedObjects
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseRelatedObjectCreation,
	|	AdditionalReportsAndDataProcessorsAssignment.Ref.UseForObjectForm,
	|	AdditionalReportsAndDataProcessorsAssignment.Ref.UseForListForm
	|INTO ttPrimaryData
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS AdditionalReportsAndDataProcessorsAssignment
	|WHERE
	|	AdditionalReportsAndDataProcessorsAssignment.RelatedObject IN(&MetadataObjectsRefs)
	|	AND AdditionalReportsAndDataProcessorsAssignment.Ref.Publication <> &PublicationNotEqual
	|	AND AdditionalReportsAndDataProcessorsAssignment.Ref.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ObjectForms.RelatedObject,
	|	FALSE AS UseObjectFilling,
	|	ObjectForms.UseReports,
	|	ObjectForms.UseRelatedObjectCreation,
	|	&ObjectFormType AS FormType
	|INTO ttResult
	|FROM
	|	ttPrimaryData AS ObjectForms
	|WHERE
	|	ObjectForms.UseForObjectForm = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	DisabledObjectForms.RelatedObject,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	&ObjectFormType
	|FROM
	|	ttPrimaryData AS DisabledObjectForms
	|WHERE
	|	DisabledObjectForms.UseForObjectForm = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	ListForms.RelatedObject,
	|	ListForms.UseObjectFilling,
	|	ListForms.UseReports,
	|	ListForms.UseRelatedObjectCreation,
	|	&ListFormType
	|FROM
	|	ttPrimaryData AS ListForms
	|WHERE
	|	ListForms.UseForListForm = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	DisabledListForms.RelatedObject,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	&ListFormType
	|FROM
	|	ttPrimaryData AS DisabledListForms
	|WHERE
	|	DisabledListForms.UseForListForm = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	tabResult.RelatedObject AS RelatedObject,
	|	tabResult.FormType,
	|	MAX(tabResult.UseObjectFilling) AS UseObjectFilling,
	|	MAX(tabResult.UseReports) AS UseReports,
	|	MAX(tabResult.UseRelatedObjectCreation) AS UseRelatedObjectCreation
	|FROM
	|	ttResult AS tabResult
	|
	|GROUP BY
	|	tabResult.RelatedObject,
	|	tabResult.FormType
	|TOTALS BY
	|	RelatedObject";
	
	If MetadataObjectReferences = Undefined Then
		QueryText = StrReplace(
			QueryText,
			"AdditionalReportsAndDataProcessorsAssignment.RelatedObject IN(&MetadataObjectsRefs)
			|	AND ",
			"");
	Else
		Query.SetParameter("MetadataObjectsRefs", MetadataObjectReferences);
	EndIf;
	
	Query.SetParameter("PublicationNotEqual", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	Query.SetParameter("KindObjectFilling",         Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling);
	Query.SetParameter("ReportKind",                     Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("KindPrintForm",             Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm);
	Query.SetParameter("KindCreateRelatedObjects", Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation);
	Query.SetParameter("ListFormType",  AdditionalReportsAndDataProcessorsClientServer.ListFormType());
	Query.SetParameter("ObjectFormType", AdditionalReportsAndDataProcessorsClientServer.ObjectFormType());
	Query.Text = QueryText;
	
	Return Query;
EndFunction

#EndRegion

#EndIf