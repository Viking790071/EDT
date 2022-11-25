#Region Public

Procedure OutputReportTitle(ReportParameters, Result) Export
	
	OutputParameters = ReportParameters.ReportSettings.OutputParameters;
	
	OutputParameter = OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If OutputParameter <> Undefined
		And (Not OutputParameter.Use Or OutputParameter.Value <> DataCompositionTextOutputType.DontOutput) Then
		OutputParameter.Use = True;
		OutputParameter.Value = DataCompositionTextOutputType.DontOutput; // disable the standard output of a title
	EndIf;
	
	OutputParameter = OutputParameters.FindParameterValue(New DataCompositionParameter("DataParametersOutput"));
	If OutputParameter <> Undefined
		And (Not OutputParameter.Use Or OutputParameter.Value <> DataCompositionTextOutputType.DontOutput) Then
		OutputParameter.Use = True;
		OutputParameter.Value = DataCompositionTextOutputType.DontOutput; // disable the parameters standard output
	EndIf;
	
	OutputParameter = OutputParameters.FindParameterValue(New DataCompositionParameter("FilterOutput"));
	If OutputParameter <> Undefined
		And (Not OutputParameter.Use Or OutputParameter.Value <> DataCompositionTextOutputType.DontOutput) Then
		OutputParameter.Use = True;
		OutputParameter.Value = DataCompositionTextOutputType.DontOutput; // disable the standard output of a filter
	EndIf;
	
	Template					= GetCommonTemplate("StandardReportCommonAreas");
	HeaderArea					= Template.GetArea("HeaderArea");
	SettingsDescriptionField	= Template.GetArea("SettingsDescription");
	
	ShowTitle = False;
	
	// Title
	If ReportParameters.TitleOutput 
		And ValueIsFilled(ReportParameters.Title) Then
		HeaderArea.Parameters.ReportHeader = GetReportTitleText(ReportParameters);
		Result.Put(HeaderArea);
		
		ShowTitle = True;
		
	EndIf;
	
	If ReportParameters.ParametersAndFiltersOutput Then
		// Filter
		TextFilter = "";
		
		If ReportParameters.Property("ParametersToBeIncludedInSelectionText")
			And TypeOf(ReportParameters.ParametersToBeIncludedInSelectionText) = Type("Array") Then
			
			For Each Parameter In ReportParameters.ParametersToBeIncludedInSelectionText Do
				If TypeOf(Parameter) <> Type("DataCompositionSettingsParameterValue")
					Or Not Parameter.Use Then
					Continue;
				EndIf;
				TextFilter = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 %2 %3 %4 ""%5""'; ru = '%1 %2 %3 %4 ""%5""';pl = '%1 %2 %3 %4 ""%5""';es_ES = '%1 %2 %3 %4 ""%5""';es_CO = '%1 %2 %3 %4 ""%5""';tr = '%1 %2 %3 %4 ""%5""';it = '%1 %2 %3 %4 ""%5""';de = '%1 %2 %3 %4 ""%5""'"),
					TextFilter,
					?(IsBlankString(TextFilter), "", NStr("en = 'and'; ru = 'и';pl = 'oraz';es_ES = 'y';es_CO = 'y';tr = 've';it = 'e';de = 'und'")),
					TrimAll(Parameter.UserSettingPresentation),
					NStr("en = 'Equal'; ru = 'Равно';pl = 'Równy';es_ES = 'Igual';es_CO = 'Igual';tr = 'Eşit';it = 'Uguale';de = 'Gleich'"),
					TrimAll(Parameter.Value));
				
			EndDo;
		EndIf;
		
		FiltersUnionMain = StringFunctionsClientServer.SubstituteParametersToString(" %1 ", NStr("en = 'and'; ru = 'и';pl = 'oraz';es_ES = 'y';es_CO = 'y';tr = 've';it = 'e';de = 'und'"));
		AddTextToFilter(TextFilter, ReportParameters.ReportSettings.FilterAvailableFields.Items, ReportParameters.ReportSettings.Filter.Items, FiltersUnionMain);
		
		If Not IsBlankString(TextFilter) Then
			SettingsDescriptionField.Parameters.NameReportSettings			= NStr("en = 'Filters:'; ru = 'Отборы:';pl = 'Filtry:';es_ES = 'Filtros:';es_CO = 'Filtros:';tr = 'Filtreler:';it = 'Filtri:';de = 'Filter:'");
			SettingsDescriptionField.Parameters.DescriptionReportSettings	= TextFilter;
			Result.Put(SettingsDescriptionField);
		EndIf;
		
		ShowTitle = True;
		
	EndIf;
	
	If ShowTitle Then
		
		Result.Area("R1:R" + Result.TableHeight).Name = "Title";
		
	EndIf;
	
EndProcedure

Function GetPeriodPresentation(ReportParameters, OnlyDates  = False) Export
	
	TextPeriod = "";
	
	If ReportParameters.Property("Period") Then
		
		If ValueIsFilled(ReportParameters.Period) Then
			TextPeriod = ?(OnlyDates, "", " on ") + Format(ReportParameters.Period, "DLF=D");
		EndIf;
		
	ElsIf ReportParameters.Property("BeginOfPeriod")
		And ReportParameters.Property("EndOfPeriod") Then
		
		BeginOfPeriod = ReportParameters.BeginOfPeriod;
		EndOfPeriod  = ReportParameters.EndOfPeriod;
		
		If ValueIsFilled(EndOfPeriod) Then 
			If EndOfPeriod >= BeginOfPeriod Then
				TextPeriod = ?(OnlyDates, "", " " + NStr("en = 'for'; ru = 'за';pl = 'dla';es_ES = 'para';es_CO = 'para';tr = 'için';it = 'per';de = 'für'") + " ") + PeriodPresentation(BegOfDay(BeginOfPeriod), EndOfDay(EndOfPeriod), "FP = True");
			Else
				TextPeriod = "";
			EndIf;
		ElsIf ValueIsFilled(BeginOfPeriod) And Not ValueIsFilled(EndOfPeriod) Then
			TextPeriod = ?(OnlyDates, "", " " + NStr("en = 'for'; ru = 'за';pl = 'dla';es_ES = 'para';es_CO = 'para';tr = 'için';it = 'per';de = 'für'") + " ") + PeriodPresentation(BegOfDay(BeginOfPeriod), EndOfDay(Date(3999, 11, 11)), "FP = True");
			TextPeriod = StrReplace(TextPeriod, Mid(TextPeriod, Find(TextPeriod, " - ")), " - ...");
		EndIf;
		
	EndIf;
	
	Return TextPeriod;
	
EndFunction

Function GetHeaderTemplate(CompositionTemplate, Body = Undefined, TemplateType = "Header") Export
	
	HaveEmptyTemplate = False;
	
	If Body = Undefined Then
		Body = CompositionTemplate.Body;
	EndIf;
	
	If Body.Count() > 0 Then
		If TemplateType = "Header" Then
			StartIndex = 0;
			EndIndex  = Body.Count();
			IteratorDirect  = True;
		ElsIf TemplateType = "Footer" Then 
			StartIndex = Body.Count() - 1;
			EndIndex  = 0;
			IteratorDirect  = False;
		EndIf;
		
		Index = StartIndex;
		While Index <> EndIndex Do
			Item = Body[Index];
			If TypeOf(Item) = Type("DataCompositionTemplateAreaTemplate") Then
				If HaveEmptyTemplate Then
					HaveEmptyTemplate = False;
				Else
					Return CompositionTemplate.Templates[Item.Template];
				EndIf;
			ElsIf TypeOf(Item) = Type("DataCompositionTemplateTableGroupTemplate") Then
				Return CompositionTemplate.Templates[Item.Template];
			ElsIf TypeOf(Item) = Type("DataCompositionTemplateChart") Then
				HaveEmptyTemplate = True;
			ElsIf TypeOf(Item) = Type("DataCompositionTemplateTable") Then
				Return CompositionTemplate.Templates[Item.HeaderTemplate];
			EndIf;
			
			If IteratorDirect Then
				Index = Index + 1;
			Else
				Index = Index - 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function SearchParametersInCompositionTemplateBody() Export
	SearchParameters = New Structure;
	
	SearchParameters.Insert("SearchInDetailedRecords", False);
	
	SearchParameters.Insert("MultipleChoice", False);
	
	SearchParameters.Insert("PropertyForIdentification", "Grouping");
	
	SearchParameters.Insert("ReturnType", "Item");
	
	SearchParameters.Insert("TemplateType", "Header");
	
	Return SearchParameters;
EndFunction

Function PickElementsFromTemplateBody(CompositionTemplate, IdentifierForSearch, SearchParameters) Export
	
	BodyItems = New Array;
	
	GetAroundCompositionTemplateBody(CompositionTemplate.Body, IdentifierForSearch, SearchParameters, BodyItems);
	
	If SearchParameters.ReturnType = "Template" Then
		
		ItemIndex = 0;
		ItemsCount = BodyItems.Count();
		While ItemIndex < ItemsCount Do

			TemplateBody = GetHeaderTemplate(CompositionTemplate, BodyItems[ItemIndex], SearchParameters.TemplateType);
			If TemplateBody = Undefined Then
				
				BodyItems.Delete(ItemIndex);
				ItemsCount = ItemsCount - 1;
				
			Else
				
				BodyItems[ItemIndex] = TemplateBody;
				ItemIndex = ItemIndex + 1;
				
			EndIf;
		
		EndDo;

	EndIf;
	
	If SearchParameters.MultipleChoice Then
		Return BodyItems;
	ElsIf BodyItems.Count() = 0 Then
		Return Undefined;
	Else
		Return BodyItems[0];
	EndIf;
	
EndFunction

Procedure GetAroundCompositionTemplateBody(ItemsColection, IdentifierForSearch, SearchParameters, BodyItems) Export
	
	For Each Item In ItemsColection Do
		
		ItemType = TypeOf(Item);
		If SearchParameters.SearchInDetailedRecords And ItemType = Type("DataCompositionTemplateRecords") Then
			
			If Item.Name = IdentifierForSearch Then

				BodyItems.Add(Item.Body);

			EndIf;
			
			Continue;
			
		EndIf;

		If SearchParameters.PropertyForIdentification = "GroupingField" Then
			
			If ItemType = Type("DataCompositionTemplateGroup")
				Or ItemType = Type("DataCompositionTemplateTableGroup") Then

				For Each GroupingItem In Item.Group Do
		
					If StrStartsWith(GroupingItem.FieldName, IdentifierForSearch) Then
						
						BodyItems.Add(Item.Body);
						BodyItems.Add(Item.HierarchicalBody);

					EndIf;
					
				EndDo;

			EndIf;
			
		ElsIf SearchParameters.PropertyForIdentification = "ItemType" Then
			
			If ItemType = Type(IdentifierForSearch) Then

				BodyItems.Add(Item);
				
			EndIf;
			
		Else
			
			If ItemType = Type("DataCompositionTemplateAreaTemplate")
				Or ItemType = Type("DataCompositionTemplateTableGroupTemplate")
				Or ItemType = Type("DataCompositionTemplateChartGroupTemplate") Then
				
				If StrStartsWith(Item.Template, IdentifierForSearch) Then
					BodyItems.Add(Item);
				EndIf;
				
			Else
				If StrStartsWith(Item.Name, IdentifierForSearch) Then
					BodyItems.Add(Item);
				EndIf;
			EndIf;
			
		EndIf;
		
		If Not SearchParameters.MultipleChoice
			And BodyItems.Count() <> 0
			And SearchParameters.ReturnType <> "Template" Then

			Return;
			
		Else
			
			If ItemType = Type("DataCompositionTemplateTable") Then
				
				SearchParameters.SearchInDetailedRecords = Not SearchParameters.SearchInDetailedRecords;
				GetAroundCompositionTemplateBody(Item.Rows, IdentifierForSearch, SearchParameters, BodyItems);
				SearchParameters.SearchInDetailedRecords = Not SearchParameters.SearchInDetailedRecords;
				
			ElsIf ItemType <> Type("DataCompositionTemplateAreaTemplate")
				And ItemType <> Type("DataCompositionTemplateTableGroupTemplate")
				And ItemType <> Type("DataCompositionTemplateChartGroupTemplate") Then

				GetAroundCompositionTemplateBody(Item.Body, IdentifierForSearch, SearchParameters, BodyItems);
				
			EndIf;
			
			If Not SearchParameters.MultipleChoice
				And BodyItems.Count() <> 0
				And SearchParameters.ReturnType <> "Template" Then
				Return;
			EndIf;
			
		EndIf;

	EndDo;
	
EndProcedure

Function FillTemplatesOfGroupingResources(Table, TemplatesArray, MapTemplatesToReportColumns, GroupingField = Undefined, IncludeNestedGroupTemplates = False, ReadResourceTemplates = False) Export
	
	For Each Grouping In Table Do
		
		If TypeOf(Grouping) = Type("DataCompositionTemplateTableGroup") Then
			
			If GroupingField = Undefined
				Or Grouping.Group.Count() > 0 And Grouping.Group[0].FieldName = GroupingField Then
				
				If IncludeNestedGroupTemplates Then
					
					FillTemplatesOfGroupingResources(Grouping.Body, TemplatesArray, MapTemplatesToReportColumns,,, True);
				Else
					FillTemplatesOfGroupingResources(Grouping.Body, TemplatesArray, MapTemplatesToReportColumns, GroupingField, IncludeNestedGroupTemplates, True);
				EndIf;
				
				For Each HierarchicalBody In Grouping.HierarchicalBody Do
					
					If TypeOf(HierarchicalBody) = Type("DataCompositionTemplateTableGroupTemplate") Then
						
						For Each ResourceTemplate In HierarchicalBody.ResourceTemplate Do
							
							TemplatesArray.Add(ResourceTemplate.Template);
							
							MapTemplatesToReportColumns.Insert(ResourceTemplate.Template, ResourceTemplate.GroupTemplate);
							
						EndDo;
						
					EndIf;
					
				EndDo;
				
			Else
				
				FillTemplatesOfGroupingResources(Grouping.Body, TemplatesArray, MapTemplatesToReportColumns, GroupingField, IncludeNestedGroupTemplates);
				
			EndIf;
			
		ElsIf TypeOf(Grouping) = Type("DataCompositionTemplateTableGroupTemplate") And ReadResourceTemplates Then
			
			For Each ResourceTemplate In Grouping.ResourceTemplate Do
				
				TemplatesArray.Add(ResourceTemplate.Template);
				
				MapTemplatesToReportColumns.Insert(ResourceTemplate.Template, ResourceTemplate.GroupTemplate);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndFunction

Function FillTemplatesOfReportFooterResources(Table, TemplatesArray, MapTemplatesToReportColumns) Export
	
	For Each Grouping In Table.Rows Do
		
		For Each ResourcesArray In Grouping.FooterTemplate.ResourceTemplate Do
			
			TemplatesArray.Add(ResourcesArray.Template);
			
			MapTemplatesToReportColumns.Insert(ResourcesArray.Template, ResourcesArray.GroupTemplate);
			
		EndDo;
		
	EndDo;
	
EndFunction

Function TotalsCount(ReportParameters) Export
	
	TotalsCount = 0;
	For Each TotalName In ReportParameters.ReportItems Do
		If ReportParameters[TotalName] Then
			TotalsCount = TotalsCount + 1;
		EndIf;
	EndDo;
	
	Return TotalsCount;
	
EndFunction

#EndRegion

#Region Private

Procedure AddTextToFilter(TextFilter, FilterFields, FilterItems, FiltersUnionText, Preffix = "")
	
	For Each FilterItem In FilterItems Do
		
		If Not FilterItem.Use
			Or FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
			Continue;
		EndIf;
		
		If TypeOf(FilterItem) = Type("DataCompositionFilterItemGroup") Then
			
			FiltersUnion = StringFunctionsClientServer.SubstituteParametersToString(" %1 ", NStr("en = 'and'; ru = 'и';pl = 'oraz';es_ES = 'y';es_CO = 'y';tr = 've';it = 'e';de = 'und'"));
			GroupPreffix = "";
			If FilterItem.GroupType = DataCompositionFilterItemsGroupType.OrGroup Then
				FiltersUnion = StringFunctionsClientServer.SubstituteParametersToString(" %1 ", NStr("en = 'or'; ru = 'или';pl = 'lub';es_ES = 'o';es_CO = 'o';tr = 'veya';it = 'o';de = 'oder'"));
			ElsIf FilterItem.GroupType = DataCompositionFilterItemsGroupType.NotGroup Then
				GroupPreffix = StringFunctionsClientServer.SubstituteParametersToString("%1 ", NStr("en = 'not'; ru = 'не';pl = 'nie';es_ES = 'no';es_CO = 'no';tr = 'değil';it = 'no';de = 'nicht'"));
			EndIf;
			
			GroupTextFilter = "";
			AddTextToFilter(GroupTextFilter, FilterFields, FilterItem.Items, FiltersUnion, GroupPreffix);
			TextFilter = StrTemplate(
				NStr("en = '%1 %2 %3(%4)'; ru = '%1 %2 %3(%4)';pl = '%1 %2 %3(%4)';es_ES = '%1 %2 %3(%4)';es_CO = '%1 %2 %3(%4)';tr = '%1 %2 %3(%4)';it = '%1 %2 %3(%4)';de = '%1 %2 %3(%4)'") + " ",
				TextFilter,
				?(IsBlankString(TextFilter), "", FiltersUnionText),
				GroupPreffix,
				GroupTextFilter);
			
			Continue;
			
		EndIf;
		
		FilterAvailableValue = FilterFields.Find(TrimAll(FilterItem.LeftValue));
		
		TextFilter = StrTemplate(
			NStr("en = '%1%2%3 %4 ""%5""'; ru = '%1%2%3 %4 ""%5""';pl = '%1%2%3 %4 ""%5""';es_ES = '%1%2%3 %4 ""%5""';es_CO = '%1%2%3 %4 ""%5""';tr = '%1%2%3 %4 ""%5""';it = '%1%2%3 %4 ""%5""';de = '%1%2%3 %4 ""%5""'"),
			TextFilter,
			?(IsBlankString(TextFilter), "", FiltersUnionText),
			FilterAvailableValue.Title,
			TrimAll(FilterItem.ComparisonType),
			TrimAll(FilterItem.RightValue));
		
	EndDo;
	
EndProcedure

Function GetReportTitleText(ReportParameters)
	
	AccountText = "";
	If ReportParameters.Property("Account") 
		And ValueIsFilled(ReportParameters.Account) Then
		
		AccountText = StrTemplate(NStr("en = 'for %1 account'; ru = 'для счета %1';pl = 'dla konta %1';es_ES = 'para la cuenta %1';es_CO = 'para la cuenta %1';tr = '%1 hesap için';it = 'per conto %1';de = 'für %1 Konto'"), ReportParameters.Account);
		
		AccountText = " " + AccountText;
	EndIf;
	
	HeaderText = ReportParameters.Title + AccountText + GetPeriodPresentation(ReportParameters);
	Return HeaderText;
	
EndFunction

#EndRegion
