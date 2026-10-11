FROM node:22-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates openssl tar \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

COPY index.js ./
# Engines are prepared inline so the image needs nothing from scripts/ at build time.
RUN KTG_DATA_DIR=/opt/ktg node -e "const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process'),{prepareRuntimeBinaries}=require('./index.js');(async()=>{const c=await prepareRuntimeBinaries();const b={};for(const[n,f,v]of[['sing-box',c.paths.singboxBin,c.singBoxVersion],['xray',c.paths.xrayBin,c.xrayVersion]]){const r=spawnSync(f,['version'],{encoding:'utf8',timeout:15000});if(r.status!==0||!r.stdout.includes(v))throw new Error(n+' version validation failed');b[n]={version:v,sha256:crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex')};}fs.writeFileSync(path.join(c.paths.binDir,'manifest.json'),JSON.stringify({platform:os.platform(),arch:os.arch(),binaries:b}),{mode:0o600});console.log('[KTG] Container engines prepared and verified.');})().catch(e=>{console.error('[KTG] Container preparation failed:',e.message);process.exit(1);});"

ENV NODE_ENV=production \
    PORT=8080 \
    KTG_BUNDLED_BIN_DIR=/opt/ktg/bin

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD node -e "const http=require('node:http');const r=http.get({host:'127.0.0.1',port:process.env.PORT||8080,path:'/healthz',timeout:2500},s=>{s.resume();process.exit(s.statusCode===200?0:1);});r.on('timeout',()=>r.destroy());r.on('error',()=>process.exit(1));"
CMD ["node", "index.js"]
