function extract_uid(r) {
    var auth = r.headersIn['Authorization'];
    if (!auth || !auth.startsWith('Bearer ')) return '';
    var parts = auth.slice(7).split('.');
    if (parts.length !== 3) return '';
    try {
        var payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
        return payload.sub || payload.user_id || '';
    } catch (e) {
        return '';
    }
}

export default { extract_uid };
