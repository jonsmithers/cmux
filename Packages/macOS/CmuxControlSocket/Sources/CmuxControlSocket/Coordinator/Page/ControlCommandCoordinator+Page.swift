internal import Foundation

/// The `page.*` domain (workspace-pages, see docs/workspace-pages-spec.md),
/// ported from PR #4766's `TerminalController.v2Page*` bodies onto the
/// coordinator/context-seam architecture.
extension ControlCommandCoordinator {
    /// Dispatches the `page.*` methods this coordinator owns; returns `nil`
    /// for anything else so the core `handle(_:)` can fall through.
    func handlePage(_ request: ControlRequest) -> ControlCallResult? {
        switch request.method {
        case "page.list":
            return pageList(request.params)
        case "page.current":
            return pageCurrent(request.params)
        case "page.create":
            return pageCreate(request.params)
        case "page.duplicate":
            return pageDuplicate(request.params)
        case "page.select":
            return pageSelect(request.params)
        case "page.close":
            return pageClose(request.params)
        case "page.reorder":
            return pageReorder(request.params)
        case "page.rename":
            return pageRename(request.params)
        case "page.next":
            return pageNext(request.params)
        case "page.previous":
            return pagePrevious(request.params)
        case "page.last":
            return pageLast(request.params)
        default:
            return nil
        }
    }

    // MARK: - Payload shaping

    private func pageSummaryPayload(_ summary: ControlPageSummary, index: Int?, selected: Bool) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(summary.id.uuidString),
            "ref": ref(.page, summary.id),
            "title": .string(summary.title),
            "selected": .bool(selected),
            "pane_count": .int(Int64(summary.paneCount)),
            "surface_count": .int(Int64(summary.surfaceCount)),
        ]
        object["index"] = index.map { JSONValue.int(Int64($0)) } ?? .null
        return .object(object)
    }

    /// The shared result payload for a resolved page mutation/read (the
    /// legacy `v2PageResultPayload`).
    private func pageResultPayload(
        windowID: UUID?,
        workspaceID: UUID,
        page: ControlPageSummary,
        index: Int?
    ) -> JSONValue {
        .object([
            "window_id": orNull(windowID?.uuidString),
            "window_ref": ref(.window, windowID),
            "workspace_id": .string(workspaceID.uuidString),
            "workspace_ref": ref(.workspace, workspaceID),
            "page_id": .string(page.id.uuidString),
            "page_ref": ref(.page, page.id),
            "page_index": index.map { JSONValue.int(Int64($0)) } ?? .null,
            "page_title": .string(page.title),
        ])
    }

    private func pageNotFoundError(_ pageID: UUID?) -> ControlCallResult {
        var data: [String: JSONValue] = [:]
        if let pageID {
            data["page_id"] = .string(pageID.uuidString)
            data["page_ref"] = ref(.page, pageID)
        }
        return .err(code: "not_found", message: "Page not found", data: data.isEmpty ? nil : .object(data))
    }

    private func pageMutationResult(_ resolution: ControlPageMutationResolution) -> ControlCallResult {
        switch resolution {
        case .tabManagerUnavailable:
            return .err(code: "unavailable", message: "TabManager not available", data: nil)
        case .workspaceNotFound:
            return .err(code: "not_found", message: "Workspace not found", data: nil)
        case .pageNotFound(let pageID):
            return pageNotFoundError(pageID)
        case .resolved(let windowID, let workspaceID, let page, let index):
            return .ok(pageResultPayload(windowID: windowID, workspaceID: workspaceID, page: page, index: index))
        }
    }

    // MARK: - page.list

    func pageList(_ params: [String: JSONValue]) -> ControlCallResult {
        switch context?.controlPageList(routing: routingSelectors(params)) ?? .tabManagerUnavailable {
        case .tabManagerUnavailable:
            return .err(code: "unavailable", message: "TabManager not available", data: nil)
        case .workspaceNotFound:
            return .err(code: "not_found", message: "Workspace not found", data: nil)
        case let .resolved(windowID, workspaceID, pages, selectedPageID):
            var payload: [String: JSONValue] = [
                "window_id": orNull(windowID?.uuidString),
                "window_ref": ref(.window, windowID),
                "workspace_id": .string(workspaceID.uuidString),
                "workspace_ref": ref(.workspace, workspaceID),
                "page_id": .string(selectedPageID.uuidString),
                "page_ref": ref(.page, selectedPageID),
                "page_count": .int(Int64(pages.count)),
            ]
            let selectedIndex = pages.firstIndex(where: { $0.id == selectedPageID })
            payload["page_index"] = selectedIndex.map { JSONValue.int(Int64($0)) } ?? .null
            payload["page_title"] = .string(pages.first(where: { $0.id == selectedPageID })?.title ?? "")
            payload["pages"] = .array(
                pages.enumerated().map { index, page in
                    pageSummaryPayload(page, index: index, selected: page.id == selectedPageID)
                }
            )
            return .ok(.object(payload))
        }
    }

    // MARK: - page.current

    func pageCurrent(_ params: [String: JSONValue]) -> ControlCallResult {
        pageMutationResult(context?.controlPageCurrent(routing: routingSelectors(params)) ?? .tabManagerUnavailable)
    }

    // MARK: - page.create

    func pageCreate(_ params: [String: JSONValue]) -> ControlCallResult {
        let title = string(params, "title")
        let select = bool(params, "select") ?? true
        return pageMutationResult(
            context?.controlPageCreate(routing: routingSelectors(params), title: title, select: select)
                ?? .tabManagerUnavailable
        )
    }

    // MARK: - page.duplicate

    func pageDuplicate(_ params: [String: JSONValue]) -> ControlCallResult {
        let pageID = uuid(params, "page_id")
        if hasNonNull(params, "page_id"), pageID == nil {
            return .err(code: "invalid_params", message: "Missing or invalid page_id", data: nil)
        }
        let title = string(params, "title")
        let select = bool(params, "select") ?? true
        return pageMutationResult(
            context?.controlPageDuplicate(routing: routingSelectors(params), pageID: pageID, title: title, select: select)
                ?? .tabManagerUnavailable
        )
    }

    // MARK: - page.select

    func pageSelect(_ params: [String: JSONValue]) -> ControlCallResult {
        guard let pageID = uuid(params, "page_id") else {
            return .err(code: "invalid_params", message: "Missing or invalid page_id", data: nil)
        }
        return pageMutationResult(
            context?.controlSelectPage(routing: routingSelectors(params), pageID: pageID) ?? .tabManagerUnavailable
        )
    }

    // MARK: - page.close

    func pageClose(_ params: [String: JSONValue]) -> ControlCallResult {
        let pageID = uuid(params, "page_id")
        if hasNonNull(params, "page_id"), pageID == nil {
            return .err(code: "invalid_params", message: "Missing or invalid page_id", data: nil)
        }
        let force = bool(params, "force") ?? true
        switch context?.controlClosePage(routing: routingSelectors(params), pageID: pageID, force: force)
            ?? .tabManagerUnavailable {
        case .tabManagerUnavailable:
            return .err(code: "unavailable", message: "TabManager not available", data: nil)
        case .workspaceNotFound:
            return .err(code: "not_found", message: "Workspace not found", data: nil)
        case .pageNotFound(let notFoundPageID):
            return pageNotFoundError(notFoundPageID)
        case .cannotCloseLastPage(let pageID):
            return .err(
                code: "invalid_state",
                message: "Cannot close the last page in a workspace",
                data: .object(["page_id": .string(pageID.uuidString), "page_ref": ref(.page, pageID)])
            )
        case let .resolved(windowID, workspaceID, closedPageID, selectedPage):
            return .ok(.object([
                "window_id": orNull(windowID?.uuidString),
                "window_ref": ref(.window, windowID),
                "workspace_id": .string(workspaceID.uuidString),
                "workspace_ref": ref(.workspace, workspaceID),
                "page_id": .string(closedPageID.uuidString),
                "page_ref": ref(.page, closedPageID),
                "selected_page_id": .string(selectedPage.id.uuidString),
                "selected_page_ref": ref(.page, selectedPage.id),
            ]))
        }
    }

    // MARK: - page.reorder

    func pageReorder(_ params: [String: JSONValue]) -> ControlCallResult {
        guard let pageID = uuid(params, "page_id") else {
            return .err(code: "invalid_params", message: "Missing or invalid page_id", data: nil)
        }
        let index = int(params, "index")
        let beforeID = uuid(params, "before_page_id")
        let afterID = uuid(params, "after_page_id")
        let targetCount = [index != nil, beforeID != nil, afterID != nil].filter { $0 }.count
        guard targetCount == 1 else {
            return .err(
                code: "invalid_params",
                message: "Specify exactly one target: index, before_page_id, or after_page_id",
                data: nil
            )
        }

        switch context?.controlReorderPage(
            routing: routingSelectors(params),
            pageID: pageID,
            toIndex: index,
            beforePageID: beforeID,
            afterPageID: afterID
        ) ?? .tabManagerUnavailable {
        case .tabManagerUnavailable:
            return .err(code: "unavailable", message: "TabManager not available", data: nil)
        case .workspaceNotFound:
            return .err(code: "not_found", message: "Workspace not found", data: nil)
        case .pageNotFound(let notFoundPageID):
            return pageNotFoundError(notFoundPageID)
        case let .anchorNotFound(anchorPageID, requestedPageID):
            return .err(
                code: "not_found",
                message: "Anchor page not found",
                data: .object([
                    "anchor_page_id": .string(anchorPageID.uuidString),
                    "page_id": .string(requestedPageID.uuidString),
                    "page_ref": ref(.page, requestedPageID),
                ])
            )
        case .cannotReorderSinglePage(let onlyPageID):
            return .err(
                code: "invalid_state",
                message: "Cannot reorder: workspace has only one page",
                data: .object(["page_id": .string(onlyPageID.uuidString), "page_ref": ref(.page, onlyPageID)])
            )
        case let .resolved(windowID, workspaceID, page, index):
            return .ok(pageResultPayload(windowID: windowID, workspaceID: workspaceID, page: page, index: index))
        }
    }

    // MARK: - page.rename

    func pageRename(_ params: [String: JSONValue]) -> ControlCallResult {
        let pageID = uuid(params, "page_id")
        if hasNonNull(params, "page_id"), pageID == nil {
            return .err(code: "invalid_params", message: "Missing or invalid page_id", data: nil)
        }
        guard let title = string(params, "title") else {
            return .err(code: "invalid_params", message: "Missing or invalid title", data: nil)
        }
        return pageMutationResult(
            context?.controlRenamePage(routing: routingSelectors(params), pageID: pageID, title: title)
                ?? .tabManagerUnavailable
        )
    }

    // MARK: - Navigation

    func pageNext(_ params: [String: JSONValue]) -> ControlCallResult {
        pageMutationResult(context?.controlSelectNextPage(routing: routingSelectors(params)) ?? .tabManagerUnavailable)
    }

    func pagePrevious(_ params: [String: JSONValue]) -> ControlCallResult {
        pageMutationResult(context?.controlSelectPreviousPage(routing: routingSelectors(params)) ?? .tabManagerUnavailable)
    }

    func pageLast(_ params: [String: JSONValue]) -> ControlCallResult {
        pageMutationResult(context?.controlSelectLastPage(routing: routingSelectors(params)) ?? .tabManagerUnavailable)
    }
}
