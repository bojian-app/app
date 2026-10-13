<script lang="ts" setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';

import { Alert, Button, Checkbox, Drawer, Input, message, Select, Space, Tag } from 'ant-design-vue';

import { requestClient } from '#/api/request';

import LiveTablePage from './live-table-page.vue';

type BenefitSource = { url: string; publisher: string; published_on?: string };
type Content = {
  company_name: string;
  province: string;
  city: string;
  industry: string;
  job_scope: string;
  valid_as_of: string;
  benefits: Record<string, string>;
  sources: Record<string, BenefitSource>;
  official_note: string;
};
type RecordItem = {
  id: number;
  content: Content;
  revision: number;
  status: string;
  review_reason?: string;
  company_id?: number;
  source_reviewed_at?: string;
  source_review_note?: string;
  history?: { decision: string; reason: string; created_at: string }[];
};

const route = useRoute();
const submissions = computed(() => route.name === 'CompanyBenefitSubmissions');
const rows = ref<RecordItem[]>([]);
const loading = ref(false);
const error = ref('');
const query = ref('');
const status = ref('');
const reason = ref('');
const detailReason = ref('');
const selected = ref<RecordItem>();
const drawer = ref(false);
const working = ref(false);
const reviewReason = ref('');
const sourceReviewNote = ref('');
const sourcesVerified = ref(false);
const publishStatus = ref('SOURCE_REVIEW');
const labels: Record<string, string> = {
  salary: '薪资结构', insurance: '五险一金', hours: '工作时间', leave: '休假制度',
  bonus: '奖金与激励', allowance: '补贴与关怀', growth: '成长与培训', other: '其他福利',
};
const states: Record<string, string> = {
  PENDING: '审核中', SOURCE_REVIEW: '待来源核验', NEEDS_MORE: '待补充公开来源',
  APPROVED: '已收录', REJECTED: '未通过', PUBLISHED: '已公开', ARCHIVED: '已下架',
};
const empty = (): Content => ({
  company_name: '', province: '', city: '', industry: '', job_scope: '',
  valid_as_of: new Date().toISOString().slice(0, 10), benefits: {}, sources: {}, official_note: '',
});
const content = ref<Content>(empty());
const columns = [
  { dataIndex: 'id', title: '编号', width: 90 },
  { key: 'company', title: '企业 / 适用范围', width: 300 },
  { key: 'city', title: '地区', width: 160 },
  { key: 'status', title: '状态', width: 140 },
  { key: 'date', title: '待遇日期', width: 150 },
  { key: 'actions', title: '操作', width: 120 },
];
const headers = (value: string) => ({ 'X-Operation-Reason': encodeURIComponent(value.trim()) });
const base = computed(() => submissions.value ? '/admin/v1/company-benefit-submissions' : '/admin/v1/company-benefits');
const publicationRequested = computed(() => submissions.value || publishStatus.value === 'PUBLISHED');
const statusOptions = computed(() => [
  { label: '全部状态', value: '' },
  ...Object.entries(states)
    .filter(([key]) => submissions.value ? !['PUBLISHED', 'ARCHIVED'].includes(key) : ['PUBLISHED', 'ARCHIVED', 'SOURCE_REVIEW'].includes(key))
    .map(([value, label]) => ({ label, value })),
]);

function failure(e: unknown) { return e instanceof Error ? e.message : '操作失败，请重试'; }

function resetSourceReview() {
  sourcesVerified.value = false;
  sourceReviewNote.value = '';
}

function editableContent(value: Content): Content {
  const copy = JSON.parse(JSON.stringify(value)) as Content;
  copy.benefits ??= {};
  copy.sources ??= {};
  for (const key of Object.keys(labels)) {
    copy.sources[key] = { url: '', publisher: '', ...copy.sources[key] };
  }
  return copy;
}

// Keep public-source links aligned with the API's hostname and port policy.
function safeSourceUrl(value?: string): string | undefined {
  try {
    const raw = value?.trim();
    if (!raw || raw.length > 2048 || /[\s\\]/.test(raw)) return;
    const authority = raw.match(/^https?:\/\/([^/?#]+)/)?.[1];
    if (!authority || authority.includes('@') || authority.endsWith(':')) return;
    const url = new URL(raw);
    if (!['http:', 'https:'].includes(url.protocol) || !url.hostname || url.username || url.password) return;
    const host = url.hostname.toLowerCase().replace(/\.$/, '');
    if (host.includes(':') || /^\d+(?:\.\d+){3}$/.test(host) || host.length > 253 || !host.includes('.')) return;
    const forbidden = ['localhost', 'local', 'internal', 'intranet', 'lan', 'home', 'home.arpa', 'test', 'invalid', 'example'];
    if (forbidden.some((suffix) => host === suffix || host.endsWith(`.${suffix}`))) return;
    const labels = host.split('.');
    if (labels.some((label) => label.length > 63 || !/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(label))) return;
    if (/^(?:\d+|0x[0-9a-f]+|0b[01]+|0o[0-7]+)$/.test(labels.at(-1) ?? '')) return;
    const rawHost = authority.split(':')[0]?.toLowerCase().replace(/\.$/, '');
    if (rawHost !== host) return;
    const port = authority.split(':')[1];
    if (port !== undefined && (!/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535)) return;
    return url.href;
  } catch { return; }
}

async function load(more = false) {
  if (!reason.value.trim()) { message.warning('请填写操作原因'); return; }
  loading.value = true;
  error.value = '';
  try {
    const result = await requestClient.get<{ items: RecordItem[] }>(base.value, {
      headers: headers(reason.value),
      params: { query: query.value, status: status.value, limit: 100, ...(more && rows.value.length ? { cursor: rows.value.at(-1)?.id } : {}) },
    });
    rows.value = more ? [...rows.value, ...result.items] : result.items;
  } catch (e) { error.value = failure(e); }
  finally { loading.value = false; }
}

function edit(item?: RecordItem) {
  selected.value = item;
  detailReason.value = '';
  reviewReason.value = '';
  content.value = editableContent(item?.content ?? empty());
  publishStatus.value = item?.status ?? 'SOURCE_REVIEW';
  resetSourceReview();
  drawer.value = true;
}

async function readRecord() {
  if (!submissions.value) return;
  if (!selected.value || !detailReason.value.trim()) { message.warning('请填写记录查阅原因'); return; }
  resetSourceReview();
  working.value = true;
  try {
    const result = await requestClient.get<RecordItem>(`${base.value}/${selected.value.id}`, { headers: headers(detailReason.value) });
    selected.value = result;
    content.value = editableContent(result.content);
    publishStatus.value = result.status;
  } catch (e) { message.error(failure(e)); }
  finally { working.value = false; }
}

function cleanContent(publishing = false): Content {
  const benefits = Object.fromEntries(Object.entries(content.value.benefits)
    .filter(([, value]) => value?.trim()).map(([key, value]) => [key, value.trim()]));
  const sources: Record<string, BenefitSource> = {};
  for (const key of Object.keys(benefits)) {
    const source = content.value.sources[key];
    if (source && (source.url?.trim() || source.publisher?.trim() || source.published_on?.trim())) {
      sources[key] = {
        url: source.url?.trim() ?? '', publisher: source.publisher?.trim() ?? '',
        ...(source.published_on?.trim() ? { published_on: source.published_on.trim() } : {}),
      };
    }
  }
  return { ...content.value, benefits, sources, official_note: publishing ? '' : content.value.official_note };
}

function validatePublication(value: Content): boolean {
  if (!Object.keys(value.benefits).length) { message.warning('请填写至少一项有合法公开来源的福利'); return false; }
  for (const key of Object.keys(value.benefits)) {
    const source = value.sources[key];
    if (!safeSourceUrl(source?.url) || !source?.publisher.trim()) {
      message.warning(`请补齐「${labels[key] ?? key}」的公开来源链接和发布主体`);
      return false;
    }
  }
  if (!sourcesVerified.value) { message.warning('发布前请逐项核验合法公开来源并勾选确认'); return false; }
  const length = [...sourceReviewNote.value.trim()].length;
  if (length < 10 || length > 1000) { message.warning('来源核验说明须为 10 至 1000 字，记录企业身份、来源及适用范围'); return false; }
  return true;
}

async function save(decision?: string) {
  if (!reason.value.trim()) { message.warning('请填写操作原因'); return; }
  if (submissions.value && !selected.value) return;
  if (submissions.value && !reviewReason.value.trim()) { message.warning('请填写反馈给用户的审核说明'); return; }
  const publishing = submissions.value ? decision === 'APPROVED' : publishStatus.value === 'PUBLISHED';
  const cleaned = cleanContent(publishing);
  if (publishing && !validatePublication(cleaned)) return;
  const sourceReview = {
    sources_verified: publishing && sourcesVerified.value,
    source_review_note: publishing ? sourceReviewNote.value.trim() : '',
  };
  working.value = true;
  try {
    if (submissions.value) {
      await requestClient.post(`${base.value}/${selected.value?.id}/decision`, {
        decision, reason: reviewReason.value.trim(), revision: selected.value?.revision,
        company_id: selected.value?.company_id, content: cleaned, ...sourceReview,
      }, { headers: headers(reason.value) });
    } else if (selected.value) {
      await requestClient.put(`${base.value}/${selected.value.id}`, {
        content: cleaned, status: publishStatus.value, revision: selected.value.revision, ...sourceReview,
      }, { headers: headers(reason.value) });
    } else {
      await requestClient.post(base.value, { content: cleaned, status: publishStatus.value, ...sourceReview }, { headers: headers(reason.value) });
    }
    message.success(submissions.value ? '审核结果已通知用户' : '平台收录已保存');
    drawer.value = false;
    await load();
  } catch (e) { message.error(failure(e)); }
  finally { working.value = false; }
}

watch(content, resetSourceReview, { deep: true, flush: 'sync' });
watch(submissions, () => { rows.value = []; drawer.value = false; status.value = submissions.value ? 'PENDING' : ''; resetSourceReview(); });
onMounted(() => { status.value = submissions.value ? 'PENDING' : ''; });
</script>

<template>
  <LiveTablePage
    :columns="columns" :data="rows" :error="error" :loading="loading"
    description="仅收录企业合法公开发布的福利信息，每项福利分别核验发布主体、来源和适用范围。"
    :title="submissions ? '企业福利收录审核' : '企业福利平台库'" @retry="load()"
  >
    <template #toolbar>
      <Space wrap>
        <Input v-model:value="reason" placeholder="操作原因（用于审计）" style="width:240px" />
        <Input v-model:value="query" placeholder="搜索企业名称" style="width:220px" />
        <Select v-model:value="status" style="width:160px" :options="statusOptions" />
        <Button type="primary" :loading="loading" @click="load()">查询</Button>
        <Button v-if="!submissions" @click="edit()">新增平台收录</Button>
        <Button :disabled="!rows.length || loading" @click="load(true)">加载更多</Button>
      </Space>
    </template>
    <template #bodyCell="{column,record}">
      <template v-if="column.key==='company'"><strong>{{ record.content.company_name }}</strong><div class="secondary">{{ record.content.job_scope }}</div></template>
      <template v-else-if="column.key==='city'">{{ record.content.province }} · {{ record.content.city }}</template>
      <template v-else-if="column.key==='date'">{{ record.content.valid_as_of }}</template>
      <template v-else-if="column.key==='status'"><Tag :color="['APPROVED','PUBLISHED'].includes(record.status) ? 'green' : ['PENDING','SOURCE_REVIEW'].includes(record.status) ? 'blue' : 'default'">{{ states[record.status] ?? record.status }}</Tag></template>
      <template v-else-if="column.key==='actions'"><Button type="link" @click="edit(record as RecordItem)">{{ submissions ? '查阅 / 审核' : '编辑收录' }}</Button></template>
    </template>
  </LiveTablePage>
  <Drawer v-model:open="drawer" :width="780" :title="submissions ? '核验公开来源' : '维护平台收录'" destroy-on-close>
    <Alert
      message="仅依据企业合法公开发布的信息收录"
      description="请逐项查阅企业官网、企业官方招聘公告等公开来源，核验企业身份及适用范围。员工群、内网、匿名泄露及未经授权的内部材料不能作为依据，不能将其改写为文字发布。适用范围与日期填写结构化字段；来源核验说明仅内部可见。"
      type="warning" show-icon class="section"
    />
    <Space v-if="submissions && selected" class="section" wrap>
      <Input v-model:value="detailReason" placeholder="填写记录查阅原因" />
      <Button :loading="working" @click="readRecord">查阅记录与审核历史</Button>
    </Space>
    <div v-if="selected?.source_reviewed_at || selected?.source_review_note" class="section review-history">
      <strong>上次来源核验</strong>
      <div v-if="selected.source_reviewed_at" class="secondary">{{ new Date(selected.source_reviewed_at).toLocaleString('zh-CN') }}</div>
      <p v-if="selected.source_review_note">{{ selected.source_review_note }}</p>
      <div class="secondary">本次发布须重新核验；历史核验不代替本次确认。</div>
    </div>
    <div v-for="(entry,index) in selected?.history" :key="index" class="section secondary">{{ states[entry.decision] ?? entry.decision }} · {{ entry.reason }} · {{ new Date(entry.created_at).toLocaleString('zh-CN') }}</div>
    <div class="section">
      <h3>企业信息</h3>
      <div class="grid">
        <label>企业完整名称<Input v-model:value="content.company_name" :maxlength="120" /></label>
        <label>行业<Input v-model:value="content.industry" :maxlength="60" /></label>
        <label>省份<Input v-model:value="content.province" :maxlength="40" /></label>
        <label>城市<Input v-model:value="content.city" :maxlength="40" /></label>
        <label>适用岗位 / 员工范围<Input v-model:value="content.job_scope" :maxlength="100" /></label>
        <label>待遇对应日期<Input v-model:value="content.valid_as_of" type="date" /></label>
      </div>
    </div>
    <div class="section">
      <div v-for="(label,key) in labels" :key="key" class="benefit section">
        <label>{{ label }}<Input.TextArea v-model:value="content.benefits[key]" :rows="3" :maxlength="2000" placeholder="仅填写该项公开来源明确支持的内容" /></label>
        <div v-if="content.benefits[key]?.trim() && content.sources[key]" class="source-fields">
          <label>该项福利的公开来源链接<Input v-model:value="content.sources[key].url" :maxlength="2000" placeholder="https://企业官网或官方招聘公告" /></label>
          <div class="grid">
            <label>发布主体<Input v-model:value="content.sources[key].publisher" :maxlength="120" placeholder="发布信息的企业或官方招聘主体" /></label>
            <label>来源发布日期（选填）<Input v-model:value="content.sources[key].published_on" type="date" /></label>
          </div>
          <a v-if="safeSourceUrl(content.sources[key].url)" :href="safeSourceUrl(content.sources[key].url)" target="_blank" rel="noopener noreferrer" referrerpolicy="no-referrer" class="source-link" @click="resetSourceReview">打开该项公开来源</a>
          <div v-else-if="content.sources[key].url" class="secondary">仅可打开有效的 HTTP / HTTPS 公开链接。</div>
        </div>
      </div>
    </div>
    <div v-if="publicationRequested" class="section source-review">
      <label>本次来源核验说明（仅内部可见）<Input.TextArea v-model:value="sourceReviewNote" :rows="3" :maxlength="1000" placeholder="记录如何核验企业身份、各项合法公开来源及适用岗位、地区和时间；10 至 1000 字" /></label>
      <Checkbox v-model:checked="sourcesVerified" class="review-confirm">我已逐项核验企业合法公开来源，确认福利内容均未超出来源及适用范围，也不包含基于保密内部材料的描述。</Checkbox>
    </div>
    <template v-if="submissions">
      <label class="section feedback">反馈给用户的审核说明<Input.TextArea v-model:value="reviewReason" :rows="3" :maxlength="1000" /></label>
      <Space v-if="['PENDING','SOURCE_REVIEW'].includes(selected?.status ?? '')" wrap>
        <Button type="primary" :loading="working" @click="save('APPROVED')">来源核验通过并收录</Button>
        <Button :loading="working" @click="save('NEEDS_MORE')">要求补充公开来源</Button>
        <Button danger :loading="working" @click="save('REJECTED')">不予收录</Button>
      </Space>
    </template>
    <Space v-else class="section" wrap>
      <Select v-model:value="publishStatus" :options="[{label:'待来源核验',value:'SOURCE_REVIEW'},{label:'公开收录',value:'PUBLISHED'},{label:'下架',value:'ARCHIVED'}]" style="width:160px" />
      <Button type="primary" :loading="working" @click="save()">保存平台收录</Button>
    </Space>
  </Drawer>
</template>

<style scoped>
.secondary{color:#8a94a5;font-size:12px;margin-top:6px}.section{margin-bottom:20px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}label{display:block;font-size:13px;color:#475569}label :deep(.ant-input){margin-top:8px}.feedback{margin-top:20px}.benefit,.review-history,.source-review{padding:16px;border:1px solid #edf0f5;border-radius:12px}.source-fields{display:grid;gap:14px;margin-top:14px}.source-link{display:inline-block}.review-confirm{margin-top:14px}.review-history p{white-space:pre-wrap;overflow-wrap:anywhere}@media(max-width:640px){.grid{grid-template-columns:1fr}}
</style>
